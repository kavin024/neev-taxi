from __future__ import annotations

from app.core.security import create_access_token
from tests.conftest import create_captain, unique_phone


def test_support_role_is_read_only_for_commercial_config(client, support_headers):
    assert client.get("/api/v1/admin/rides", headers=support_headers).status_code == 200
    response = client.post(
        "/api/v1/admin/pricing",
        json={"category": "bike", "per_km_paise": 1200},
        headers=support_headers,
    )
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "forbidden"


def test_admin_can_update_pricing_and_audit_records_it(client, admin_headers):
    before = client.get("/api/v1/admin/pricing", headers=admin_headers)
    assert before.status_code == 200
    rule = before.json()[0]

    response = client.patch(
        f"/api/v1/admin/pricing/{rule['id']}",
        json={"per_km_paise": rule["per_km_paise"] + 100},
        headers=admin_headers,
    )
    assert response.status_code == 200, response.text
    assert response.json()["version"] == rule["version"] + 1

    after = client.get("/api/v1/admin/pricing", headers=admin_headers).json()
    updated = next(item for item in after if item["id"] == rule["id"])
    assert updated["per_km_paise"] == rule["per_km_paise"] + 100

    logs = client.get("/api/v1/admin/audit-logs", headers=admin_headers)
    assert logs.status_code == 200
    entries = logs.json()["items"] if isinstance(logs.json(), dict) else logs.json()
    assert any(
        entry["action"] in {"pricing.update", "pricing.updated"} for entry in entries
    )


def test_admin_approves_pending_captain_and_suspends_them(client, db, admin_headers):
    from app.models import CaptainDocument

    phone = unique_phone()
    user = create_captain(db, phone, category="bike", approved=False)

    listing = client.get(
        "/api/v1/admin/captains?verification_status=pending", headers=admin_headers
    )
    assert listing.status_code == 200

    # Approval fails closed until the required paperwork and a vehicle exist.
    premature = client.post(
        f"/api/v1/admin/captains/{user.id}/decision",
        json={"approved": True, "reason": "Documents verified in test"},
        headers=admin_headers,
    )
    assert premature.status_code == 409
    assert "driving_license" in premature.json()["error"]["details"]["missing"]

    for doc_type in ("driving_license", "vehicle_rc", "insurance", "profile_photo"):
        db.add(
            CaptainDocument(
                captain_id=user.id,
                doc_type=doc_type,
                storage_key=f"tests/{user.id}/{doc_type}.jpg",
                original_filename=f"{doc_type}.jpg",
                mime_type="image/jpeg",
                size_bytes=1024,
                checksum="0" * 64,
                status="pending",
            )
        )
    db.commit()

    approved = client.post(
        f"/api/v1/admin/captains/{user.id}/decision",
        json={"approved": True, "reason": "Documents verified in test"},
        headers=admin_headers,
    )
    assert approved.status_code == 200, approved.text
    assert approved.json()["verification_status"] == "approved"

    suspended = client.post(
        f"/api/v1/admin/captains/{user.id}/status",
        json={"suspended": True, "reason": "Test suspension"},
        headers=admin_headers,
    )
    assert suspended.status_code == 200, suspended.text
    assert suspended.json()["status"] == "suspended"


def test_unauthenticated_admin_requests_are_rejected(client):
    for path in ("/api/v1/admin/dashboard", "/api/v1/admin/rides", "/api/v1/admin/captains"):
        response = client.get(path)
        assert response.status_code == 401


def test_captain_token_cannot_access_admin_api(client, captain):
    response = client.get("/api/v1/admin/dashboard", headers=captain["headers"])
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_token"


def test_dashboard_and_exports(client, admin_headers):
    dashboard = client.get("/api/v1/admin/dashboard", headers=admin_headers)
    assert dashboard.status_code == 200
    data = dashboard.json()
    assert "rides_today" in data["kpis"]
    assert "active_rides" in data["kpis"]
    assert data["ride_series"]

    export = client.get("/api/v1/admin/exports/rides.csv", headers=admin_headers)
    assert export.status_code == 200
    assert "text/csv" in export.headers["content-type"]
    assert export.text.splitlines()[0].startswith("ride_id,category,status")


def test_admin_sees_trip_events_and_safety(client, admin_headers, passenger, captain):
    from tests.conftest import complete_ride

    ride, _ = complete_ride(client, passenger, captain, "admin-ride-0001")
    detail = client.get(f"/api/v1/admin/rides/{ride['id']}", headers=admin_headers)
    assert detail.status_code == 200
    assert detail.json()["id"] == ride["id"]
    assert detail.json()["events"]

    incidents = client.get("/api/v1/admin/safety-incidents", headers=admin_headers)
    assert incidents.status_code == 200
