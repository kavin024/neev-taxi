from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor

from app.core.security import create_access_token
from tests.conftest import create_captain, request_ride, unique_phone


def _captain_with_token(db, phone: str):
    user = create_captain(db, phone, category="bike", lat=12.9757, lng=77.6068)
    token, _ = create_access_token(user.id, "captain", token_version=user.token_version)
    return user.id, {"Authorization": f"Bearer {token}"}


def test_exactly_one_captain_wins_a_race(client, db, passenger):
    ids = []
    headers = []
    for _ in range(4):
        captain_id, header = _captain_with_token(db, unique_phone())
        ids.append(captain_id)
        headers.append(header)

    ride = request_ride(client, passenger["headers"], key="dispatch-race-0001")
    assert ride["offers_sent"] >= 4

    def accept(header):
        response = client.post(
            f"/api/v1/captain/offers/{ride['id']}/accept", headers=header
        )
        return response.status_code

    with ThreadPoolExecutor(max_workers=4) as pool:
        statuses = list(pool.map(accept, headers))

    assert statuses.count(200) == 1, statuses
    assert statuses.count(409) == 3, statuses

    winner = headers[statuses.index(200)]
    final = client.get(f"/api/v1/rides/{ride['id']}", headers=passenger["headers"])
    assert final.status_code == 200
    assert final.json()["status"] == "assigned"
    assert final.json()["trip"]["state"] == "captain_arriving"

    # A losing captain cannot retry into an assigned ride.
    loser = next(h for h, s in zip(headers, statuses) if s == 409)
    retry = client.post(f"/api/v1/captain/offers/{ride['id']}/accept", headers=loser)
    assert retry.status_code == 409
    assert retry.json()["error"]["code"] == "ride_unavailable"


def test_rejecting_an_offer_removes_it(client, db, passenger):
    _, header = _captain_with_token(db, unique_phone())
    ride = request_ride(client, passenger["headers"], key="dispatch-reject-0001")

    rejected = client.post(
        f"/api/v1/captain/offers/{ride['id']}/reject", headers=header
    )
    assert rejected.status_code == 200

    offers = client.get("/api/v1/captain/offers", headers=header)
    assert all(item["ride_id"] != ride["id"] for item in offers.json()["items"])

    accept = client.post(
        f"/api/v1/captain/offers/{ride['id']}/accept", headers=header
    )
    assert accept.status_code == 409
    assert accept.json()["error"]["code"] == "not_offered"


def test_offline_or_unapproved_captain_receives_no_offers(client, db, passenger):
    from tests.conftest import create_captain

    offline = create_captain(db, unique_phone(), category="bike", online=False)
    unapproved = create_captain(db, unique_phone(), category="bike", approved=False)
    for user in (offline, unapproved):
        token, _ = create_access_token(user.id, "captain", token_version=0)
        header = {"Authorization": f"Bearer {token}"}
        # Unapproved captains are blocked before the offer list is even queried.
        response = client.get("/api/v1/captain/offers", headers=header)
        if user is unapproved:
            assert response.status_code == 403
            assert response.json()["error"]["code"] == "captain_not_approved"
        else:
            assert response.status_code == 200
            assert response.json()["items"] == []
