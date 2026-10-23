from __future__ import annotations

from tests.conftest import PICKUP, DROP, auth_header, quote


def test_quote_has_itemised_fare_and_demo_route(client, passenger):
    data = quote(client, passenger["headers"])
    assert data["category"] == "bike"
    assert data["distance_m"] > 0
    assert data["duration_s"] > 0
    assert data["total_paise"] > 0
    labels = [line["label"] for line in data["lines"]]
    assert "Base fare" in labels
    assert any(label.startswith("Distance") for label in labels)
    assert any(label.startswith("Time") for label in labels)
    assert "Platform fee" in labels
    assert data["route_provider"] == "demo"
    assert data["approximate_route"] is True
    assert len(data["route_points"]) >= 2
    assert data["quote_token"]


def test_quote_applies_coupon(client, passenger):
    plain = quote(client, passenger["headers"])
    discounted = quote(client, passenger["headers"], coupon="NEEV50")
    assert discounted["coupon_code"] == "NEEV50"
    assert discounted["discount_paise"] == min(plain["total_paise"] // 2, 5000)
    assert discounted["total_paise"] == plain["total_paise"] - discounted["discount_paise"]


def test_unknown_coupon_is_rejected(client, passenger):
    response = client.post(
        "/api/v1/fares/quote",
        json={
            "category": "bike",
            "pickup": PICKUP,
            "drop": DROP,
            "coupon_code": "NOTREAL",
        },
        headers=passenger["headers"],
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "coupon_invalid"


def test_pickup_and_drop_must_differ(client, passenger):
    response = client.post(
        "/api/v1/fares/quote",
        json={"category": "bike", "pickup": PICKUP, "drop": PICKUP},
        headers=passenger["headers"],
    )
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_captain_cannot_request_a_ride(client, captain):
    response = client.post(
        "/api/v1/rides/request",
        json={
            "category": "bike",
            "pickup": PICKUP,
            "drop": DROP,
            "idempotency_key": "captain-cannot-ride",
            "use_power_pass": False,
        },
        headers=captain["headers"],
    )
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "forbidden"


def test_power_pass_purchase_then_discount(client, passenger):
    status = client.get("/api/v1/passenger/power-pass", headers=passenger["headers"])
    assert status.status_code == 200
    plans = status.json()["plans"]
    assert plans and plans[0]["code"] == "POWER30"

    response = client.post(
        "/api/v1/passenger/power-pass/purchase",
        json={
            "plan_id": plans[0]["id"],
            "method": "mock_upi",
            "idempotency_key": "power-pass-test-0001",
        },
        headers=passenger["headers"],
    )
    assert response.status_code == 201, response.text
    payment = response.json()
    assert payment["sandbox"] is True

    confirm = client.post(
        f"/api/v1/payments/{payment['payment_id']}/sandbox-confirm",
        json={"outcome": "success", "idempotency_key": "power-pass-confirm-0001"},
        headers=passenger["headers"],
    )
    assert confirm.status_code == 200, confirm.text
    assert confirm.json()["status"] == "captured"

    status = client.get("/api/v1/passenger/power-pass", headers=passenger["headers"])
    assert status.json()["active"]["rides_remaining"] == plans[0]["ride_limit"]

    discounted = quote(client, passenger["headers"], use_power_pass=True)
    assert discounted["power_pass_applied"] is True
    assert discounted["discount_paise"] > 0
