from __future__ import annotations

from datetime import datetime, timezone

from tests.conftest import DROP, PICKUP, request_ride


def test_full_ride_lifecycle(client, passenger, captain):
    ride = request_ride(client, passenger["headers"], key="lifecycle-ride-0001")
    assert ride["status"] == "searching"
    assert ride["quoted_fare_paise"] > 0
    assert ride["payment_method"] == "cash"
    assert ride["offers_sent"] >= 1

    offers = client.get("/api/v1/captain/offers", headers=captain["headers"])
    assert offers.status_code == 200
    assert any(item["ride_id"] == ride["id"] for item in offers.json()["items"])

    accepted = client.post(
        f"/api/v1/captain/offers/{ride['id']}/accept", headers=captain["headers"]
    )
    assert accepted.status_code == 200, accepted.text
    trip = accepted.json()["trip"]
    assert trip["state"] == "captain_arriving"
    assert trip["start_pin"] is None, "captain must never receive the passenger PIN"

    passenger_view = client.get(f"/api/v1/rides/{ride['id']}", headers=passenger["headers"])
    assert passenger_view.status_code == 200
    trip = passenger_view.json()["trip"]
    pin = trip["start_pin"]
    assert pin and len(pin) == 4

    arrived = client.post(
        f"/api/v1/captain/trips/{trip['id']}/arrived", headers=captain["headers"]
    )
    assert arrived.status_code == 200

    wrong = client.post(
        f"/api/v1/captain/trips/{trip['id']}/start",
        json={"pin": "0000" if pin != "0000" else "1111"},
        headers=captain["headers"],
    )
    assert wrong.status_code == 401
    assert wrong.json()["error"]["code"] == "pin_invalid"

    started = client.post(
        f"/api/v1/captain/trips/{trip['id']}/start",
        json={"pin": pin},
        headers=captain["headers"],
    )
    assert started.status_code == 200, started.text
    assert started.json()["trip"]["state"] == "in_progress"

    location = client.post(
        f"/api/v1/captain/trips/{trip['id']}/location",
        json={
            "lat": 12.9730,
            "lng": 77.6200,
            "accuracy_m": 12,
            "speed_mps": 8,
            "heading": 90,
            "recorded_at": datetime.now(timezone.utc).isoformat(),
            "source": "simulated",
        },
        headers=captain["headers"],
    )
    assert location.status_code == 200, location.text
    assert location.json()["source"] == "simulated"

    history = client.get(
        f"/api/v1/rides/{ride['id']}/locations", headers=passenger["headers"]
    )
    assert history.status_code == 200
    assert history.json()["items"][-1]["source"] == "simulated"
    assert history.json()["simulated"] is True

    share = client.post(
        f"/api/v1/rides/{ride['id']}/share",
        json={"duration_minutes": 60},
        headers=passenger["headers"],
    )
    assert share.status_code == 201, share.text
    token = share.json()["url"].rsplit("/", 1)[-1]
    live_view = client.get(f"/api/v1/public/trips/share/{token}")
    assert live_view.status_code == 200
    assert live_view.json()["live"] is True
    assert live_view.json()["last_location"]["simulated"] is True
    assert live_view.json()["captain"]["name"]
    assert "phone" not in live_view.json()["captain"]

    completed = client.post(
        f"/api/v1/captain/trips/{trip['id']}/complete",
        json={"lat": DROP["lat"], "lng": DROP["lng"]},
        headers=captain["headers"],
    )
    assert completed.status_code == 200, completed.text
    body = completed.json()
    assert body["status"] == "completed"
    assert body["trip"]["state"] == "completed"
    assert body["trip"]["drop_verified"] is True

    cash = client.post(
        f"/api/v1/payments/rides/{ride['id']}/cash-confirm",
        headers=passenger["headers"],
    )
    assert cash.status_code == 200, cash.text
    assert cash.json()["status"] == "captured"

    paid = client.get(f"/api/v1/rides/{ride['id']}", headers=passenger["headers"])
    assert paid.json()["trip"]["payment_status"] == "paid"

    rated = client.post(
        f"/api/v1/rides/{ride['id']}/rate",
        json={"stars": 5, "comment": "Clean and on time", "tags": ["clean"]},
        headers=passenger["headers"],
    )
    assert rated.status_code == 200, rated.text
    assert rated.json()["stars"] == 5

    duplicate_rating = client.post(
        f"/api/v1/rides/{ride['id']}/rate",
        json={"stars": 4},
        headers=passenger["headers"],
    )
    assert duplicate_rating.status_code == 409

    closed_view = client.get(f"/api/v1/public/trips/share/{token}")
    assert closed_view.status_code == 200, closed_view.text
    assert closed_view.json()["trip_state"] == "completed"
    assert closed_view.json()["last_location"] is None
    page = client.get(f"/share/{token}")
    assert page.status_code == 200
    assert "neev" in page.text.lower()


def test_cannot_start_trip_without_accepting(client, passenger, captain):
    ride = request_ride(client, passenger["headers"], key="no-accept-ride-0001")
    response = client.post(
        f"/api/v1/captain/trips/{ride['id']}/arrived", headers=captain["headers"]
    )
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "trip_not_found"


def test_passenger_cannot_see_another_passengers_ride(client, passenger):
    from tests.conftest import unique_phone

    ride = request_ride(client, passenger["headers"], key="private-ride-0001")
    from app.core.security import create_access_token
    from app.core.database import SessionLocal
    from app.models import PassengerProfile, User

    with SessionLocal() as db:
        other = User(phone=unique_phone(), role="passenger", phone_verified=True, is_demo=True)
        db.add(other)
        db.flush()
        db.add(PassengerProfile(user_id=other.id, name="Other Passenger"))
        db.commit()
        token, _ = create_access_token(other.id, "passenger")

    response = client.get(
        f"/api/v1/rides/{ride['id']}", headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "forbidden"


def test_idempotent_ride_request_returns_same_ride(client, passenger):
    first = request_ride(client, passenger["headers"], key="idempotent-ride-0001")
    second = request_ride(client, passenger["headers"], key="idempotent-ride-0001")
    assert first["id"] == second["id"]
    assert client.get("/api/v1/rides", headers=passenger["headers"]).json()["total"] == 1
