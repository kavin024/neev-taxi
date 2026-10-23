from __future__ import annotations

from datetime import datetime, timedelta
from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import api_error, get_passenger
from app.core.database import get_db, utcnow
from app.models import (
    PowerPassPlan,
    User,
    UserPowerPass,
)
from app.schemas.auth import PassengerProfileUpdate
from app.schemas.rides import QuoteBody, QuoteOut
from app.services.auth_service import serialize_user
from app.services.fare_service import (
    FareError,
    compute_quote,
    get_active_power_pass,
    quote_token_for,
    save_estimate,
)
from app.services.ledger_service import balance_paise
from app.services.payment_service import create_power_pass_payment
from app.services.ride_service import money

router = APIRouter(tags=["fares and passenger account"])


@router.post("/fares/quote", response_model=QuoteOut)
def quote(
    body: QuoteBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_passenger),
):
    try:
        result = compute_quote(
            db,
            user,
            body.category,
            body.pickup.model_dump(),
            body.drop.model_dump(),
            body.coupon_code,
            body.use_power_pass,
        )
    except FareError as exc:
        raise api_error(exc.status_code, exc.code, exc.message, exc.details)
    estimate = save_estimate(db, user, result, body.pickup.model_dump(), body.drop.model_dump())
    db.commit()
    return QuoteOut(
        category=result.category,
        distance_m=result.distance_m,
        duration_s=result.duration_s,
        total_paise=result.total_paise,
        total_display=money(result.total_paise),
        lines=result.lines,
        coupon_code=result.coupon_code,
        discount_paise=result.coupon_discount_paise + result.power_pass_discount_paise,
        power_pass_applied=result.power_pass is not None,
        power_pass_id=result.power_pass.id if result.power_pass else None,
        surge_multiplier=result.surge_multiplier,
        pricing_version=result.pricing_version,
        quote_token=quote_token_for(estimate),
        expires_at=estimate.expires_at,
        route_points=[[p[0], p[1]] for p in result.route_points],
        approximate_route=result.approximate_route,
        route_provider=result.route_provider,
    )


@router.get("/passenger/profile")
def get_profile(user: User = Depends(get_passenger), db: Session = Depends(get_db)):
    data = serialize_user(user, db)
    data["wallet_balance_paise"] = balance_paise(db, "passenger_wallet", user.id)
    data["wallet_balance_display"] = money(balance_paise(db, "passenger_wallet", user.id))
    return data


@router.put("/passenger/profile")
def update_profile(
    body: PassengerProfileUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_passenger),
):
    profile = user.passenger_profile
    if not profile:
        raise api_error(409, "profile_missing", "Passenger profile unavailable.")
    for key, value in body.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(profile, key, value)
    db.commit()
    return serialize_user(user, db)


class PowerPassPurchaseBody(BaseModel):
    plan_id: str
    method: Literal["mock_upi", "upi", "card", "wallet"] = "mock_upi"
    idempotency_key: str = Field(min_length=8, max_length=100)


@router.get("/passenger/power-pass")
def power_pass_status(db: Session = Depends(get_db), user: User = Depends(get_passenger)):
    now = utcnow()
    plans = db.scalars(
        select(PowerPassPlan).where(PowerPassPlan.is_active.is_(True)).order_by(PowerPassPlan.price_paise)
    ).all()
    active = db.scalars(
        select(UserPowerPass)
        .where(UserPowerPass.user_id == user.id)
        .order_by(UserPowerPass.created_at.desc())
    ).all()
    active_pass = next(
        (p for p in active if p.status == "active" and p.expires_at > now and p.rides_used < p.rides_total),
        None,
    )
    return {
        "plans": [
            {
                "id": p.id,
                "code": p.code,
                "name": p.name,
                "description": p.description,
                "price_paise": p.price_paise,
                "price_display": money(p.price_paise),
                "discount_pct": p.discount_pct,
                "max_discount_paise": p.max_discount_paise,
                "ride_limit": p.ride_limit,
                "validity_days": p.validity_days,
            }
            for p in plans
        ],
        "active": {
            "id": active_pass.id,
            "plan_id": active_pass.plan_id,
            "rides_used": active_pass.rides_used,
            "rides_total": active_pass.rides_total,
            "rides_remaining": active_pass.rides_total - active_pass.rides_used,
            "expires_at": active_pass.expires_at,
            "status": active_pass.status,
        }
        if active_pass
        else None,
        "history": [
            {
                "id": p.id,
                "status": p.status,
                "rides_used": p.rides_used,
                "rides_total": p.rides_total,
                "starts_at": p.starts_at,
                "expires_at": p.expires_at,
            }
            for p in active
            if p != active_pass
        ],
    }


@router.post("/passenger/power-pass/purchase", status_code=201)
def purchase_power_pass(
    body: PowerPassPurchaseBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_passenger),
):
    payment = create_power_pass_payment(
        db, user, body.plan_id, body.method, body.idempotency_key
    )
    return {
        "payment_id": payment.id,
        "status": payment.status,
        "provider": payment.provider,
        "amount_paise": payment.amount_paise,
        "amount_display": money(payment.amount_paise),
        "sandbox": payment.provider == "sandbox",
        "provider_order_id": payment.provider_order_id,
        "next": "Confirm the sandbox payment from the app."
        if payment.provider == "sandbox" and payment.status == "created"
        else "Power Pass activated."
        if payment.status == "captured"
        else "Complete payment with the provider.",
    }


@router.get("/passenger/wallet")
def wallet(db: Session = Depends(get_db), user: User = Depends(get_passenger)):
    balance = balance_paise(db, "passenger_wallet", user.id)
    return {
        "balance_paise": balance,
        "balance_display": money(balance),
        "sandbox_topups_only": True,
    }


@router.get("/passenger/wallet/transactions")
def wallet_transactions(db: Session = Depends(get_db), user: User = Depends(get_passenger)):
    from app.models import LedgerEntry

    rows = db.scalars(
        select(LedgerEntry)
        .where(LedgerEntry.user_id == user.id, LedgerEntry.account_type == "passenger_wallet")
        .order_by(LedgerEntry.created_at.desc())
        .limit(100)
    ).all()
    return [
        {
            "id": r.id,
            "type": r.entry_type,
            "amount_paise": r.amount_paise,
            "amount_display": money(r.amount_paise),
            "description": r.description,
            "created_at": r.created_at,
            "metadata": r.metadata_json,
        }
        for r in rows
    ]
