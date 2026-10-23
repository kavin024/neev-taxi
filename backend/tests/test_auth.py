from __future__ import annotations

from sqlalchemy import select

from app.models import User
from tests.conftest import auth_header, make_phone, otp_login


def test_otp_request_and_verify_creates_passenger(client, db):
    phone = make_phone("9876500001")
    response = client.post(
        "/api/v1/auth/otp/request", json={"phone": phone, "role": "passenger"}
    )
    assert response.status_code == 200
    body = response.json()
    assert body["phone"] == phone
    assert body["dev_otp"] == "123456"
    assert body["delivery"] == "outbox_simulated"

    response = client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": body["dev_otp"], "role": "passenger"},
    )
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["access_token"] and data["refresh_token"]
    assert data["user"]["role"] == "passenger"
    assert data["user"]["phone_verified"] is True
    user = db.scalar(select(User).where(User.phone == phone))
    assert user and user.is_demo is False


def test_wrong_otp_is_rejected_and_counted(client):
    phone = make_phone("9876500002")
    client.post("/api/v1/auth/otp/request", json={"phone": phone, "role": "passenger"})
    response = client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": "000000", "role": "passenger"},
    )
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "otp_invalid"
    assert response.json()["error"]["details"]["attempts_remaining"] == 4


def test_role_mismatch_between_apps(client, passenger):
    response = client.post(
        "/api/v1/auth/otp/request", json={"phone": passenger["phone"], "role": "captain"}
    )
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "role_mismatch"


def test_refresh_rotation_and_reuse_detection(client, passenger):
    refresh_token = None
    phone = make_phone("9876500003")
    tokens = otp_login(client, phone, "passenger")
    refresh_token = tokens["refresh_token"]

    response = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert response.status_code == 200, response.text
    rotated = response.json()["refresh_token"]
    assert rotated != refresh_token

    # Reusing the old token is treated as theft and revokes the whole family.
    response = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "refresh_reused"

    response = client.post("/api/v1/auth/refresh", json={"refresh_token": rotated})
    assert response.status_code == 401


def test_logout_all_revokes_access_tokens(client):
    phone = make_phone("9876500004")
    tokens = otp_login(client, phone, "passenger")
    headers = auth_header(tokens["access_token"])
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 200

    response = client.post("/api/v1/auth/logout-all", headers=headers)
    assert response.status_code == 200
    response = client.get("/api/v1/auth/me", headers=headers)
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "session_revoked"


def test_admin_login_rejects_bad_password_and_returns_roles(client):
    response = client.post(
        "/api/v1/admin/auth/login",
        json={"email": "admin@neev.local", "password": "definitely-wrong"},
    )
    assert response.status_code == 401

    response = client.post(
        "/api/v1/admin/auth/login",
        json={"email": "admin@neev.local", "password": "NeevAdmin!2026"},
    )
    assert response.status_code == 200, response.text
    admin = response.json()["admin"]
    assert admin["role"] == "super_admin"
    assert "password" not in admin and "password_hash" not in admin
