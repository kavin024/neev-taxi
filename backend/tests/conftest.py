"""Test configuration.

Tests run against a real PostgreSQL database (embedded pgserver by default).
The schema is created from the SQLAlchemy metadata for speed; Alembic
migrations are exercised separately by `test_migrations.py`.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

BACKEND = Path(__file__).resolve().parents[1]
ROOT = BACKEND.parent
sys.path.insert(0, str(BACKEND))
sys.path.insert(0, str(ROOT))

PGDATA = os.environ.get("NEEV_TEST_PG_DATA", "/tmp/opencode/pgdata-test")
TEST_DB = os.environ.get("NEEV_TEST_DB", "neev_test")

if not os.environ.get("NEEV_DATABASE_URL"):
    import pgserver

    Path(PGDATA).mkdir(parents=True, exist_ok=True)
    _server = pgserver.get_server(PGDATA, cleanup_mode=None)
    try:
        _server.psql(f"CREATE DATABASE {TEST_DB};")
    except Exception:
        pass
    os.environ["NEEV_DATABASE_URL"] = (
        f"postgresql+psycopg://postgres@/{TEST_DB}?host={PGDATA}"
    )

os.environ["NEEV_APP_ENV"] = "test"
os.environ["NEEV_SECRET_KEY"] = "test-only-secret-key-0123456789abcdefghijklmnop"
os.environ["NEEV_DEV_OTP_ENABLED"] = "true"
os.environ["NEEV_DEV_OTP_FIXED_CODE"] = "123456"
os.environ["NEEV_DEV_OTP_RETURN_CODE"] = "true"
os.environ["NEEV_DEV_ALLOW_GPS_SIMULATION"] = "true"
os.environ["NEEV_PAYMENT_PROVIDER"] = "sandbox"
os.environ["NEEV_SMS_PROVIDER"] = "outbox"
os.environ["NEEV_MAP_PROVIDER"] = "demo"
os.environ["NEEV_RUN_BACKGROUND_JOBS"] = "false"

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import select  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

import app.models  # noqa: E402,F401
from app.core.database import Base, SessionLocal, engine  # noqa: E402
from app.core.rate_limit import limiter  # noqa: E402
from app.main import app  # noqa: E402
from app.models import (  # noqa: E402
    CaptainProfile,
    PassengerProfile,
    ServiceArea,
    ServiceCategory,
    User,
    Vehicle,
)
from app.core.security import create_access_token  # noqa: E402


@pytest.fixture(scope="session", autouse=True)
def _schema():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    yield
    Base.metadata.drop_all(engine)


@pytest.fixture(autouse=True)
def _reset_rate_limiter():
    limiter._events.clear()
    yield
    limiter._events.clear()


@pytest.fixture(autouse=True)
def _isolate_captains(_schema):
    """Each test starts with no captain online.

    Dispatch deliberately caps offers; leftover online captains from earlier
    tests would otherwise hide the captain this test created.
    """
    from sqlalchemy import update

    with SessionLocal() as db:
        db.execute(update(CaptainProfile).values(is_online=False))
        db.commit()
    yield


@pytest.fixture(scope="session")
def client():
    return TestClient(app)


@pytest.fixture
def db() -> Session:
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture(scope="session", autouse=True)
def _catalog(_schema):
    from scripts.seed_demo import seed

    seed()
    yield


def auth_header(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def otp_login(client: TestClient, phone: str, role: str = "passenger") -> dict:
    response = client.post(
        "/api/v1/auth/otp/request", json={"phone": phone, "role": role}
    )
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["dev_otp"], "development OTP must be returned in the test environment"
    response = client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": data["dev_otp"], "role": role},
    )
    assert response.status_code == 200, response.text
    return response.json()


def make_phone(seed: str) -> str:
    """Deterministic +91 number for a test."""
    digits = "".join(ch for ch in seed if ch.isdigit())[:10].ljust(10, "7")
    return "+91" + digits


def unique_phone(prefix: str = "9") -> str:
    import secrets

    # 10 digits, valid Indian mobile prefix, unique per test run.
    return f"+91{prefix}{secrets.randbelow(10**9):09d}"


def create_captain(
    db: Session,
    phone: str,
    *,
    category: str = "bike",
    lat: float = 12.9757,
    lng: float = 77.6068,
    online: bool = True,
    approved: bool = True,
    name: str | None = None,
    reg: str | None = None,
) -> User:
    user = db.scalar(select(User).where(User.phone == phone))
    if not user:
        user = User(phone=phone, role="captain", phone_verified=True, is_demo=True)
        db.add(user)
        db.flush()
    area = db.scalar(select(ServiceArea))
    profile = db.get(CaptainProfile, user.id)
    if not profile:
        profile = CaptainProfile(
            user_id=user.id,
            name=name or f"Test Captain {phone[-4:]}",
            verification_status="approved" if approved else "pending",
            is_online=online,
            online_since=None,
            last_lat=lat,
            last_lng=lng,
            last_location_at=None,
            last_location_source="demo-fixture",
            service_area_id=area.id if area else None,
        )
        db.add(profile)
    else:
        profile.verification_status = "approved" if approved else "pending"
        profile.is_online = online
        profile.last_lat = lat
        profile.last_lng = lng
    vehicle = db.scalar(
        select(Vehicle).where(
            Vehicle.captain_id == user.id, Vehicle.category == category
        )
    )
    if not vehicle:
        db.add(
            Vehicle(
                captain_id=user.id,
                category=category,
                reg_number=reg or f"KA99TE{abs(hash(phone)) % 10000:04d}",
                make_model="Test Vehicle",
                is_active=True,
            )
        )
    db.commit()
    db.refresh(profile)
    from app.core.database import utcnow

    profile.last_location_at = utcnow()
    db.commit()
    return user


@pytest.fixture
def passenger(db):
    phone = unique_phone()
    user = User(phone=phone, role="passenger", phone_verified=True, is_demo=True)
    db.add(user)
    db.flush()
    db.add(PassengerProfile(user_id=user.id, name="Test Passenger"))
    db.commit()
    token, _ = create_access_token(user.id, "passenger", token_version=user.token_version)
    return {"id": user.id, "phone": phone, "headers": auth_header(token)}


@pytest.fixture
def captain(db, _isolate_captains):
    phone = unique_phone()
    user = create_captain(db, phone, category="bike")
    token, _ = create_access_token(user.id, "captain", token_version=user.token_version)
    return {"id": user.id, "phone": phone, "headers": auth_header(token)}


@pytest.fixture
def admin_headers(client):
    response = client.post(
        "/api/v1/admin/auth/login",
        json={"email": "admin@neev.local", "password": "NeevAdmin!2026"},
    )
    assert response.status_code == 200, response.text
    return auth_header(response.json()["access_token"])


@pytest.fixture
def support_headers(client):
    response = client.post(
        "/api/v1/admin/auth/login",
        json={"email": "support@neev.local", "password": "NeevSupport!2026"},
    )
    assert response.status_code == 200, response.text
    return auth_header(response.json()["access_token"])


PICKUP = {
    "address": "MG Road Metro, Bengaluru",
    "lat": 12.9757,
    "lng": 77.6068,
}
DROP = {
    "address": "Indiranagar 100ft Road, Bengaluru",
    "lat": 12.9719,
    "lng": 77.6412,
}


def quote(client, headers, category="bike", coupon=None, use_power_pass=False):
    payload = {
        "category": category,
        "pickup": PICKUP,
        "drop": DROP,
        "use_power_pass": use_power_pass,
    }
    if coupon:
        payload["coupon_code"] = coupon
    response = client.post("/api/v1/fares/quote", json=payload, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def request_ride(client, headers, category="bike", key="test-ride-key-0001", method="cash", coupon=None):
    payload = {
        "category": category,
        "pickup": PICKUP,
        "drop": DROP,
        "use_power_pass": False,
        "idempotency_key": key,
        "payment_method": method,
    }
    if coupon:
        payload["coupon_code"] = coupon
    response = client.post("/api/v1/rides/request", json=payload, headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


def complete_ride(client, passenger, captain, key: str, method: str = "cash") -> tuple[dict, dict]:
    """Run request → accept → arrive → start → complete and return ride + trip."""
    ride = request_ride(client, passenger["headers"], key=key, method=method)
    accepted = client.post(
        f"/api/v1/captain/offers/{ride['id']}/accept", headers=captain["headers"]
    )
    assert accepted.status_code == 200, accepted.text
    trip = accepted.json()["trip"]

    view = client.get(f"/api/v1/rides/{ride['id']}", headers=passenger["headers"])
    pin = view.json()["trip"]["start_pin"]
    assert client.post(
        f"/api/v1/captain/trips/{trip['id']}/arrived", headers=captain["headers"]
    ).status_code == 200
    started = client.post(
        f"/api/v1/captain/trips/{trip['id']}/start",
        json={"pin": pin},
        headers=captain["headers"],
    )
    assert started.status_code == 200, started.text
    completed = client.post(
        f"/api/v1/captain/trips/{trip['id']}/complete",
        json={"lat": DROP["lat"], "lng": DROP["lng"]},
        headers=captain["headers"],
    )
    assert completed.status_code == 200, completed.text
    final = client.get(f"/api/v1/rides/{ride['id']}", headers=passenger["headers"]).json()
    return final, final["trip"]
