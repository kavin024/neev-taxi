from __future__ import annotations

from tests.conftest import complete_ride


def test_cash_payment_is_confirmed_explicitly(client, passenger, captain):
    ride, trip = complete_ride(client, passenger, captain, "pay-cash-0001", method="cash")
    assert trip["payment_status"] == "pending"

    cash = client.post(
        f"/api/v1/payments/rides/{ride['id']}/cash-confirm",
        headers=passenger["headers"],
    )
    assert cash.status_code == 200, cash.text
    body = cash.json()
    assert body["method"] == "cash"
    assert body["status"] == "captured"
    assert body["sandbox"] is False

    again = client.post(
        f"/api/v1/payments/rides/{ride['id']}/cash-confirm",
        headers=passenger["headers"],
    )
    assert again.status_code == 200
    assert again.json()["id"] == body["id"]


def test_sandbox_upi_success_and_ledger(client, passenger, captain):
    ride, _ = complete_ride(client, passenger, captain, "pay-sandbox-0001", method="mock_upi")

    created = client.post(
        f"/api/v1/payments/rides/{ride['id']}",
        json={"method": "mock_upi", "idempotency_key": "sandbox-pay-0001"},
        headers=passenger["headers"],
    )
    assert created.status_code == 201, created.text
    payment = created.json()
    assert payment["sandbox"] is True
    assert payment["status"] == "created"
    assert payment["provider_order_id"].startswith("sbx_order_")

    confirmed = client.post(
        f"/api/v1/payments/{payment['id']}/sandbox-confirm",
        json={"outcome": "success", "idempotency_key": "sandbox-confirm-0001"},
        headers=passenger["headers"],
    )
    assert confirmed.status_code == 200, confirmed.text
    assert confirmed.json()["status"] == "captured"
    assert confirmed.json()["signature_verified"] is True

    history = client.get("/api/v1/payments/history", headers=passenger["headers"])
    assert history.status_code == 200
    assert any(item["id"] == payment["id"] for item in history.json()["payments"])

    final = client.get(f"/api/v1/rides/{ride['id']}", headers=passenger["headers"])
    assert final.json()["trip"]["payment_status"] == "paid"


def test_sandbox_failure_can_be_retried(client, passenger, captain):
    ride, _ = complete_ride(client, passenger, captain, "pay-fail-0001", method="mock_upi")
    created = client.post(
        f"/api/v1/payments/rides/{ride['id']}",
        json={"method": "mock_upi", "idempotency_key": "sandbox-fail-0001"},
        headers=passenger["headers"],
    ).json()

    failed = client.post(
        f"/api/v1/payments/{created['id']}/sandbox-confirm",
        json={"outcome": "failure", "idempotency_key": "sandbox-fail-confirm-0001"},
        headers=passenger["headers"],
    )
    assert failed.status_code == 200
    assert failed.json()["status"] == "failed"
    assert failed.json()["failure_reason"]

    retried = client.post(
        f"/api/v1/payments/{created['id']}/sandbox-confirm",
        json={"outcome": "success", "idempotency_key": "sandbox-retry-confirm-0001"},
        headers=passenger["headers"],
    )
    assert retried.status_code == 200
    assert retried.json()["status"] == "captured"


def test_razorpay_route_fails_closed_when_unconfigured(client, passenger, captain):
    ride, _ = complete_ride(client, passenger, captain, "pay-razorpay-0001", method="card")
    response = client.post(
        f"/api/v1/payments/rides/{ride['id']}",
        json={"method": "card", "idempotency_key": "card-pay-0001"},
        headers=passenger["headers"],
    )
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "payment_provider_unconfigured"


def test_wallet_payment_rejects_insufficient_balance(client, passenger, captain):
    ride, _ = complete_ride(client, passenger, captain, "pay-wallet-0001", method="wallet")
    response = client.post(
        f"/api/v1/payments/rides/{ride['id']}",
        json={"method": "wallet", "idempotency_key": "wallet-pay-0001"},
        headers=passenger["headers"],
    )
    assert response.status_code == 402
    assert response.json()["error"]["code"] == "wallet_insufficient"


def test_payment_methods_are_honest_about_sandbox(client):
    response = client.get("/api/v1/payments/methods")
    assert response.status_code == 200
    data = response.json()
    sandbox = next(m for m in data["methods"] if m["code"] == "mock_upi")
    assert sandbox["enabled"] is True
    assert "Test-only" in sandbox["warning"]
    assert data["razorpay_configured"] is False
    assert "card" not in [m["code"] for m in data["methods"]]
