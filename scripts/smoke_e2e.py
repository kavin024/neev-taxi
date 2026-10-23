#!/usr/bin/env python3
"""End-to-end smoke test against a running Neev API.

Exercises the full happy path over HTTP: health, passenger/captain OTP login,
captain duty + location, category and fare quote, ride request, offer, accept,
arrival, PIN start, location ping, completion, cash payment and earnings.

Usage:
    .venv/bin/python scripts/smoke_e2e.py [--base-url http://127.0.0.1:8000]

Expects a freshly seeded development database (scripts/dev_backend.py). It creates a
new passenger account per run, but reuses the seeded bike captain; if that captain is
already on an active trip the smoke test will fail — reset the demo data or wait.
"""
from __future__ import annotations

import argparse
import secrets
import sys
import time
import uuid

import httpx

CAPTAIN_PHONE = "+919000000011"


def check(resp: httpx.Response, label: str, expected: int = 200):
    if resp.status_code != expected:
        print(f"FAIL {label}: {resp.status_code} {resp.text[:800]}")
        sys.exit(1)
    print(f"ok   {label}")
    return resp.json() if resp.content else None


def login(client: httpx.Client, base: str, phone: str, role: str) -> str:
    otp = check(
        client.post(f"{base}/api/v1/auth/otp/request", json={"phone": phone, "role": role}),
        f"{role} otp request",
    )
    code = otp.get("dev_otp") or "123456"
    tokens = check(
        client.post(
            f"{base}/api/v1/auth/otp/verify",
            json={"phone": phone, "code": code, "role": role},
        ),
        f"{role} otp verify",
    )
    return tokens["access_token"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    args = parser.parse_args()
    base = args.base_url.rstrip("/")

    # A fresh passenger per run avoids "active ride" collisions.
    passenger_phone = f"+919{secrets.randbelow(10**9):09d}"
    run_id = uuid.uuid4().hex[:12]

    with httpx.Client(timeout=20) as client:
        health = check(client.get(f"{base}/health"), "health")
        assert health["database"] == "ok", health

        passenger = login(client, base, passenger_phone, "passenger")
        captain = login(client, base, CAPTAIN_PHONE, "captain")
        ph = {"Authorization": f"Bearer {passenger}"}
        ch = {"Authorization": f"Bearer {captain}"}

        check(
            client.post(
                f"{base}/api/v1/captain/availability",
                headers=ch,
                json={"is_online": True, "lat": 12.9716, "lng": 77.5946},
            ),
            "captain online",
        )

        cats = check(client.get(f"{base}/api/v1/catalog/categories", headers=ph), "categories")
        assert any(c["code"] == "bike" for c in cats)

        quote = check(
            client.post(
                f"{base}/api/v1/fares/quote",
                headers=ph,
                json={
                    "category": "bike",
                    "pickup": {
                        "lat": 12.9716,
                        "lng": 77.5946,
                        "address": "MG Road, Bengaluru",
                    },
                    "drop": {
                        "lat": 12.9569,
                        "lng": 77.6011,
                        "address": "Jayanagar, Bengaluru",
                    },
                },
            ),
            "fare quote",
        )
        assert quote["total_paise"] > 0 and quote["lines"], quote

        ride = check(
            client.post(
                f"{base}/api/v1/rides/request",
                headers=ph,
                json={
                    "category": "bike",
                    "pickup": {
                        "lat": 12.9716,
                        "lng": 77.5946,
                        "address": "MG Road, Bengaluru",
                    },
                    "drop": {
                        "lat": 12.9569,
                        "lng": 77.6011,
                        "address": "Jayanagar, Bengaluru",
                    },
                    "payment_method": "cash",
                    "idempotency_key": f"smoke-ride-{run_id}",
                    "quote_token": quote["quote_token"],
                },
            ),
            "ride request",
            expected=201,
        )
        ride_id = ride["id"]

        offers = check(
            client.get(f"{base}/api/v1/captain/offers", headers=ch), "captain offers"
        )["items"]
        assert any(o["ride_id"] == ride_id for o in offers), offers

        accepted = check(
            client.post(f"{base}/api/v1/captain/offers/{ride_id}/accept", headers=ch),
            "accept ride",
        )
        trip_id = accepted["trip"]["id"]

        passenger_view = check(
            client.get(f"{base}/api/v1/rides/{ride_id}", headers=ph), "ride after accept"
        )
        pin = passenger_view["trip"]["start_pin"]
        assert pin and len(pin) == 4

        check(
            client.post(f"{base}/api/v1/captain/trips/{trip_id}/arrived", headers=ch),
            "arrived",
        )
        check(
            client.post(
                f"{base}/api/v1/captain/trips/{trip_id}/start",
                headers=ch,
                json={"pin": pin},
            ),
            "start with pin",
        )
        check(
            client.post(
                f"{base}/api/v1/captain/trips/{trip_id}/location",
                headers=ch,
                json={
                    "lat": 12.9650,
                    "lng": 77.5980,
                    "recorded_at": time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime()),
                    "source": "gps",
                },
            ),
            "location update",
        )
        completed = check(
            client.post(
                f"{base}/api/v1/captain/trips/{trip_id}/complete",
                headers=ch,
                json={"lat": 12.9569, "lng": 77.6011},
            ),
            "complete trip",
        )
        assert completed["trip"]["state"] == "completed", completed

        payment = check(
            client.post(
                f"{base}/api/v1/payments/rides/{ride_id}/cash-confirm",
                headers=ph,
                json={"idempotency_key": f"smoke-cash-{run_id}"},
            ),
            "cash payment",
        )
        assert payment["status"] in {"captured", "settled", "succeeded", "paid"}, payment

        earnings = check(client.get(f"{base}/api/v1/captain/earnings", headers=ch), "earnings")
        assert "lifetime_paise" in earnings

        print(
            f"\nsmoke passed: ride {ride_id}, quote ₹{quote['total_paise'] / 100:.2f}, "
            f"captain lifetime ₹{earnings['lifetime_paise'] / 100:.2f}"
        )


if __name__ == "__main__":
    main()
