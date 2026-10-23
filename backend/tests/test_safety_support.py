from __future__ import annotations

from tests.conftest import complete_ride


def test_sos_is_recorded_but_never_claims_emergency_dispatch(client, passenger):
    response = client.post(
        "/api/v1/safety/sos",
        json={"lat": 12.9757, "lng": 77.6068, "press_hold_ms": 3500, "note": "Test"},
        headers=passenger["headers"],
    )
    assert response.status_code == 201, response.text
    data = response.json()
    assert data["status"] == "active"
    assert data["emergency_services_contacted"] is False
    assert data["safety_team_notified"] is False
    assert "No emergency service" in data["disclaimer"]

    active = client.get("/api/v1/safety/sos/active", headers=passenger["headers"])
    assert active.json()["active"]["id"] == data["incident_id"]

    cancelled = client.post(
        f"/api/v1/safety/sos/{data['incident_id']}/cancel",
        headers=passenger["headers"],
    )
    assert cancelled.status_code == 200
    assert cancelled.json()["status"] == "cancelled"

    history = client.get("/api/v1/safety/sos/history", headers=passenger["headers"])
    assert history.json()[0]["status"] == "cancelled"

    # A cancelled false alarm does not lock the passenger out of a real SOS.
    second = client.post(
        "/api/v1/safety/sos",
        json={"press_hold_ms": 3000},
        headers=passenger["headers"],
    )
    assert second.status_code == 201


def test_short_sos_press_is_rejected(client, passenger):
    response = client.post(
        "/api/v1/safety/sos",
        json={"press_hold_ms": 1000},
        headers=passenger["headers"],
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "sos_hold_too_short"


def test_sos_can_attach_to_a_live_ride_and_admin_sees_it(client, passenger, captain, admin_headers):
    from tests.conftest import DROP, request_ride

    ride = request_ride(client, passenger["headers"], key="sos-ride-0001")
    accepted = client.post(
        f"/api/v1/captain/offers/{ride['id']}/accept", headers=captain["headers"]
    )
    assert accepted.status_code == 200

    response = client.post(
        "/api/v1/safety/sos",
        json={
            "ride_request_id": ride["id"],
            "lat": 12.9757,
            "lng": 77.6068,
            "press_hold_ms": 3000,
        },
        headers=passenger["headers"],
    )
    assert response.status_code == 201, response.text

    incidents = client.get("/api/v1/admin/safety-incidents", headers=admin_headers)
    assert any(i["id"] == response.json()["incident_id"] for i in incidents.json())


def test_support_ticket_lifecycle_and_admin_resolution(client, passenger, admin_headers, support_headers):
    created = client.post(
        "/api/v1/support/tickets",
        json={
            "category": "payment",
            "subject": "Cash payment not showing",
            "description": "I paid cash but the trip still shows pending.",
        },
        headers=passenger["headers"],
    )
    assert created.status_code == 201, created.text
    ticket = created.json()
    assert ticket["status"] == "open"

    reply = client.post(
        f"/api/v1/support/tickets/{ticket['id']}/messages",
        json={"body": "Any update?"},
        headers=passenger["headers"],
    )
    assert reply.status_code == 201

    detail = client.get(
        f"/api/v1/support/tickets/{ticket['id']}", headers=passenger["headers"]
    )
    assert detail.status_code == 200
    assert len(detail.json()["messages"]) == 2

    queue = client.get("/api/v1/admin/tickets", headers=support_headers)
    assert queue.status_code == 200
    assert any(t["id"] == ticket["id"] for t in queue.json()["items"])

    admin_reply = client.post(
        f"/api/v1/admin/tickets/{ticket['id']}/reply",
        json={"body": "We checked the ledger; your cash payment is confirmed."},
        headers=support_headers,
    )
    assert admin_reply.status_code in (200, 201), admin_reply.text

    resolved = client.post(
        f"/api/v1/admin/tickets/{ticket['id']}/resolve",
        json={"resolution_notes": "Payment confirmed and ledger reconciled.", "status": "resolved"},
        headers=support_headers,
    )
    assert resolved.status_code == 200, resolved.text
    assert resolved.json()["status"] == "resolved"


def test_cannot_read_another_users_ticket(client, passenger):
    from app.core.database import SessionLocal
    from app.core.security import create_access_token
    from app.models import PassengerProfile, User
    from tests.conftest import unique_phone

    created = client.post(
        "/api/v1/support/tickets",
        json={
            "category": "app",
            "subject": "Private ticket",
            "description": "Only the owner should read this.",
        },
        headers=passenger["headers"],
    ).json()

    with SessionLocal() as db:
        other = User(phone=unique_phone(), role="passenger", phone_verified=True, is_demo=True)
        db.add(other)
        db.flush()
        db.add(PassengerProfile(user_id=other.id, name="Other"))
        db.commit()
        token, _ = create_access_token(other.id, "passenger")

    response = client.get(
        f"/api/v1/support/tickets/{created['id']}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 404


def test_notifications_are_created_for_trip_events(client, passenger, captain):
    complete_ride(client, passenger, captain, "notify-ride-0001")
    notifications = client.get("/api/v1/notifications", headers=passenger["headers"])
    assert notifications.status_code == 200
    items = notifications.json()["items"] if isinstance(notifications.json(), dict) else notifications.json()
    types = {item["type"] for item in items}
    assert "ride.accepted" in types
    assert "trip.completed" in types
