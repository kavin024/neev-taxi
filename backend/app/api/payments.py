from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import api_error, get_current_user, get_passenger
from app.core.config import settings
from app.core.database import get_db
from app.models import PaymentTransaction, Refund, User
from app.schemas.rides import MockPaymentConfirmBody, PaymentCreateBody, RefundRequestBody
from app.services.payment_service import (
    after_payment,
    confirm_cash,
    create_ride_payment,
    create_wallet_topup,
    handle_razorpay_webhook,
    razorpay_configured,
    request_refund,
    sandbox_confirm,
)
from app.services.ride_service import money

router = APIRouter(prefix="/payments", tags=["payments"])


class WalletTopupBody(BaseModel):
    amount_paise: int = Field(ge=10000, le=500000)
    method: str = Field(default="mock_upi", pattern="^(mock_upi|upi|card)$")
    idempotency_key: str = Field(min_length=8, max_length=100)


def serialize_payment(p: PaymentTransaction) -> dict:
    return {
        "id": p.id,
        "purpose": p.purpose,
        "ride_request_id": p.ride_request_id,
        "trip_id": p.trip_id,
        "amount_paise": p.amount_paise,
        "amount_display": money(p.amount_paise),
        "currency": p.currency,
        "method": p.method,
        "provider": p.provider,
        "provider_order_id": p.provider_order_id,
        "status": p.status,
        "signature_verified": p.signature_verified,
        "failure_reason": p.failure_reason,
        "sandbox": p.provider == "sandbox",
        "created_at": p.created_at,
        "captured_at": p.captured_at,
    }


@router.get("/methods")
def payment_methods():
    methods = [
        {"code": "cash", "label": "Cash", "enabled": True, "provider": "cash"},
        {
            "code": "mock_upi",
            "label": "Sandbox UPI",
            "enabled": settings.is_dev and settings.payment_provider == "sandbox",
            "provider": "sandbox",
            "warning": "Test-only. No real money moves.",
        },
    ]
    if razorpay_configured():
        methods += [
            {"code": "upi", "label": "UPI", "enabled": True, "provider": "razorpay"},
            {"code": "card", "label": "Card", "enabled": True, "provider": "razorpay"},
        ]
    return {
        "methods": methods,
        "razorpay_configured": razorpay_configured(),
        "provider": settings.payment_provider,
        "note": "Card details are never handled by Neev. Razorpay tokenisation would apply when configured.",
    }


@router.post("/rides/{ride_id}", status_code=201)
async def create_payment(
    ride_id: str,
    body: PaymentCreateBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_passenger),
):
    payment = create_ride_payment(
        db, user, ride_id, body.method, body.idempotency_key
    )
    data = serialize_payment(payment)
    if payment.method == "mock_upi" and payment.status == "created":
        data["sandbox_confirm_endpoint"] = f"/api/v1/payments/{payment.id}/sandbox-confirm"
        data["warning"] = "Sandbox checkout. Confirm success or failure explicitly; no real funds move."
    if payment.method == "cash" and payment.status == "pending":
        data["next"] = "Confirm cash handed over after paying the captain."
    return data


@router.post("/{payment_id}/sandbox-confirm")
async def confirm_sandbox(
    payment_id: str,
    body: MockPaymentConfirmBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    payment = db.get(PaymentTransaction, payment_id)
    if not payment or payment.user_id != user.id:
        raise api_error(404, "payment_not_found", "Payment not found.")
    payment = sandbox_confirm(db, payment, body.outcome)
    await after_payment(db, payment)
    return serialize_payment(payment)


@router.post("/rides/{ride_id}/cash-confirm")
async def confirm_cash_payment(
    ride_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_passenger),
):
    payment = confirm_cash(db, user, ride_id)
    await after_payment(db, payment)
    return serialize_payment(payment)


@router.get("/history")
def payment_history(
    db: Session = Depends(get_db), user: User = Depends(get_current_user)
):
    rows = db.scalars(
        select(PaymentTransaction)
        .where(PaymentTransaction.user_id == user.id)
        .order_by(PaymentTransaction.created_at.desc())
        .limit(100)
    ).all()
    refunds = db.scalars(
        select(Refund).where(Refund.user_id == user.id).order_by(Refund.created_at.desc())
    ).all()
    return {
        "payments": [serialize_payment(p) for p in rows],
        "refunds": [
            {
                "id": r.id,
                "payment_id": r.payment_id,
                "amount_paise": r.amount_paise,
                "amount_display": money(r.amount_paise),
                "reason": r.reason,
                "status": r.status,
                "created_at": r.created_at,
                "processed_at": r.processed_at,
            }
            for r in refunds
        ],
    }


@router.post("/{payment_id}/refund", status_code=201)
def create_refund(
    payment_id: str,
    body: RefundRequestBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    refund = request_refund(db, user, payment_id, body.reason)
    return {
        "id": refund.id,
        "status": refund.status,
        "amount_paise": refund.amount_paise,
        "amount_display": money(refund.amount_paise),
        "note": "A support agent reviews every refund request. A request is not a completed refund.",
    }


@router.post("/wallet/topup", status_code=201)
def wallet_topup(
    body: WalletTopupBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_passenger),
):
    payment = create_wallet_topup(
        db, user, body.amount_paise, body.method, body.idempotency_key
    )
    return serialize_payment(payment)


@router.post("/webhooks/razorpay")
async def razorpay_webhook(request: Request, db: Session = Depends(get_db)):
    raw = await request.body()
    signature = request.headers.get("X-Razorpay-Signature", "")
    payment = handle_razorpay_webhook(db, raw, signature)
    if payment:
        await after_payment(db, payment)
    return {"received": True, "payment_id": payment.id if payment else None}
