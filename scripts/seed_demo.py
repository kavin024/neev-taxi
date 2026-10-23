#!/usr/bin/env python3
"""Idempotent demo seed for local development.

Every record created here is clearly marked as demo data where the schema
supports it (users.is_demo, names prefixed "Demo"). It never runs in
production: the command refuses unless NEEV_APP_ENV is development/test.
"""
from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
# Settings load .env/.env.local relative to the process CWD; keep behaviour the
# same whether the script is launched from the repo root or from backend/.
os.chdir(BACKEND)
sys.path.insert(0, str(BACKEND))

from sqlalchemy import select  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.core.database import SessionLocal, utcnow  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.models import (  # noqa: E402
    AdminUser,
    AppSetting,
    CaptainProfile,
    Coupon,
    PassengerProfile,
    PowerPassPlan,
    PricingRule,
    ServiceArea,
    ServiceCategory,
    User,
    Vehicle,
)

DEMO_PASSWORD = os.environ.get("NEEV_DEMO_ADMIN_PASSWORD", "NeevAdmin!2026")
SUPPORT_PASSWORD = os.environ.get("NEEV_DEMO_SUPPORT_PASSWORD", "NeevSupport!2026")

CATEGORIES = [
    ("bike", "Neev Bike", "Fast solo rides through city traffic", 1, "bike", 1),
    ("auto", "Neev Auto", "Metered comfort for up to three", 3, "auto", 2),
    ("cab", "Neev Cab", "Air-conditioned four-seater", 4, "cab", 3),
]

PRICING = {
    "bike": dict(base_fare_paise=2500, minimum_fare_paise=4000, per_km_paise=1100, per_minute_paise=150),
    "auto": dict(base_fare_paise=3500, minimum_fare_paise=5000, per_km_paise=1500, per_minute_paise=180),
    "cab": dict(base_fare_paise=5000, minimum_fare_paise=8000, per_km_paise=1900, per_minute_paise=250),
}

CAPTAINS = [
    {
        "phone": "+919000000011",
        "name": "Demo Captain Ravi",
        "category": "bike",
        "reg": "KA01ND0001",
        "model": "TVS Apache RTR 160",
        "color": "Matte black",
        "lat": 12.9738,
        "lng": 77.6102,
    },
    {
        "phone": "+919000000012",
        "name": "Demo Captain Suresh",
        "category": "auto",
        "reg": "KA01ND0002",
        "model": "Bajaj RE",
        "color": "Green",
        "lat": 12.9560,
        "lng": 77.6010,
    },
    {
        "phone": "+919000000013",
        "name": "Demo Captain Imran",
        "category": "cab",
        "reg": "KA01ND0003",
        "model": "Maruti Suzuki Dzire",
        "color": "White",
        "lat": 12.9788,
        "lng": 77.5912,
    },
]


def get_or_create(db: Session, model, defaults: dict, **lookup):
    row = db.scalar(select(model).filter_by(**lookup))
    if row:
        return row, False
    row = model(**lookup, **defaults)
    db.add(row)
    db.flush()
    return row, True


def seed(reset_demo: bool = False) -> dict:
    if settings.is_production:
        raise SystemExit("Refusing to seed demo data in production.")

    created: dict[str, int] = {}
    with SessionLocal() as db:
        if reset_demo:
            for user in db.scalars(select(User).where(User.is_demo.is_(True))).all():
                db.delete(user)
            db.commit()

        area, made = get_or_create(
            db,
            ServiceArea,
            dict(
                city="Bengaluru",
                center_lat=12.9716,
                center_lng=77.5946,
                radius_km=35.0,
                is_active=True,
            ),
            name="Bengaluru Central",
        )
        created["service_area"] = int(made)

        for code, name, desc, capacity, icon, order in CATEGORIES:
            _, made = get_or_create(
                db,
                ServiceCategory,
                dict(
                    display_name=name,
                    description=desc,
                    capacity=capacity,
                    icon=icon,
                    sort_order=order,
                    is_active=True,
                ),
                code=code,
            )
            created[f"category_{code}"] = int(made)

        for category, fares in PRICING.items():
            _, made = get_or_create(
                db,
                PricingRule,
                dict(
                    service_area_id=area.id,
                    base_fare_paise=fares["base_fare_paise"],
                    minimum_fare_paise=fares["minimum_fare_paise"],
                    per_km_paise=fares["per_km_paise"],
                    per_minute_paise=fares["per_minute_paise"],
                    waiting_per_minute_paise=200,
                    cancellation_fee_paise=2000,
                    platform_fee_paise=500,
                    commission_pct=20.0,
                    night_multiplier=1.25,
                    is_active=True,
                ),
                category=category,
            )
            created[f"pricing_{category}"] = int(made)

        _, made = get_or_create(
            db,
            Coupon,
            dict(
                description="Demo launch offer: 50% off, capped at ₹50.",
                discount_type="percent",
                value=50,
                max_discount_paise=5000,
                min_fare_paise=0,
                max_uses=5000,
                per_user_limit=4,
                categories=None,
                valid_until=utcnow() + timedelta(days=365),
                is_active=True,
            ),
            code="NEEV50",
        )
        created["coupon"] = int(made)

        _, made = get_or_create(
            db,
            PowerPassPlan,
            dict(
                name="Neev Power Pass",
                description="10% off every ride for 30 days, up to ₹40 off per ride.",
                price_paise=9900,
                discount_pct=10,
                max_discount_paise=4000,
                ride_limit=20,
                validity_days=30,
                is_active=True,
            ),
            code="POWER30",
        )
        created["power_pass"] = int(made)

        settings_seed = {
            "support": {
                "value": {
                    "email": "support@neev.local",
                    "hours": "09:00-21:00 IST (demo)",
                    "emergency_note": "Call 112 for emergencies. Neev does not contact emergency services automatically in this build.",
                },
                "description": "Support contact details shown in the apps.",
            },
            "dispatch": {
                "value": {"max_offers": settings.max_offers_per_request, "radius_km": settings.dispatch_radius_km},
                "description": "Read-only snapshot of dispatch configuration for the admin console.",
            },
            "demo_data": {
                "value": {"enabled": True, "warning": "All seeded accounts and rides are synthetic demo data."},
                "description": "Marks this environment as containing demo data.",
            },
        }
        for key, item in settings_seed.items():
            _, made = get_or_create(
                db,
                AppSetting,
                dict(value=item["value"], description=item["description"]),
                key=key,
            )
            created[f"setting_{key}"] = int(made)

        admins = [
            ("admin@neev.local", "Demo Super Admin", DEMO_PASSWORD, "super_admin"),
            ("support@neev.local", "Demo Support", SUPPORT_PASSWORD, "support"),
        ]
        for email, name, password, role in admins:
            existing = db.scalar(select(AdminUser).where(AdminUser.email == email))
            if existing:
                created[f"admin_{email}"] = 0
                continue
            db.add(
                AdminUser(
                    email=email,
                    name=name,
                    password_hash=hash_password(password),
                    role=role,
                )
            )
            created[f"admin_{email}"] = 1

        passengers = [
            ("+919000000001", "Demo Passenger Aarav", "aarav.demo@example.test"),
            ("+919000000002", "Demo Passenger Meera", "meera.demo@example.test"),
        ]
        for phone, name, email in passengers:
            existing = db.scalar(select(User).where(User.phone == phone))
            if existing:
                created[f"passenger_{phone}"] = 0
                continue
            user = User(phone=phone, role="passenger", phone_verified=True, is_demo=True)
            db.add(user)
            db.flush()
            db.add(
                PassengerProfile(
                    user_id=user.id,
                    name=name,
                    email=email,
                    home_area="Indiranagar, Bengaluru",
                    total_rides=0,
                )
            )
            created[f"passenger_{phone}"] = 1

        for item in CAPTAINS:
            existing = db.scalar(select(User).where(User.phone == item["phone"]))
            if existing:
                created[f"captain_{item['phone']}"] = 0
                continue
            user = User(phone=item["phone"], role="captain", phone_verified=True, is_demo=True)
            db.add(user)
            db.flush()
            profile = CaptainProfile(
                user_id=user.id,
                name=item["name"],
                email=f"{item['phone']}@example.test",
                verification_status="approved",
                dl_masked="KA-DL-****0001",
                pan_masked="ABCDE****F",
                aadhaar_masked="XXXX XXXX 0001",
                is_online=True,
                online_since=utcnow(),
                last_lat=item["lat"],
                last_lng=item["lng"],
                last_location_at=utcnow(),
                last_location_source="demo-fixture",
                service_area_id=area.id,
                payout_upi="demo@upi",
                approved_at=utcnow(),
            )
            db.add(profile)
            db.add(
                Vehicle(
                    captain_id=user.id,
                    category=item["category"],
                    reg_number=item["reg"],
                    make_model=item["model"],
                    color=item["color"],
                    year=2022,
                    is_active=True,
                )
            )
            created[f"captain_{item['phone']}"] = 1

        db.commit()

    created["total"] = sum(created.values())
    return created


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed Neev demo data (idempotent)")
    parser.add_argument(
        "--reset-demo",
        action="store_true",
        help="Delete demo users (their rides cascade) before seeding",
    )
    args = parser.parse_args()
    result = seed(reset_demo=args.reset_demo)
    print("Demo seed complete:")
    for key, value in result.items():
        print(f"  {key}: {'created' if value else 'exists'}")
    print("\nDemo sign-ins (development only):")
    print("  Passenger OTP: 9000000001, code from NEEV_DEV_OTP_FIXED_CODE (default 123456)")
    print("  Captain OTP:   9000000011 (bike), 9000000012 (auto), 9000000013 (cab)")
    print(f"  Admin:         admin@neev.local / {DEMO_PASSWORD}")
    print(f"  Support:       support@neev.local / {SUPPORT_PASSWORD}")


if __name__ == "__main__":
    main()
