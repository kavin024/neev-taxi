from __future__ import annotations

import hashlib
import hmac
import logging
import secrets
from datetime import datetime, timedelta, timezone

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import api_error
from app.core.config import settings
from app.core.database import utcnow
from app.models import (
    PaymentTransaction,
    PowerPassPlan,
    RideRequest,
    Trip,
    User,
    UserPowerPass,
)
from app.services.ledger_service import (
    captain_available_paise,
    post_trip_earnings,
    post_wallet_topup,
)
from app.services.realtime import add_ride_event, envelope, manager, notify_user

logger = logging.getLogger("neev.payments")

PAYABLE_METHODS = {"cash", "mock_upi", "upi", "card", "wallet"}


def sandbox_signature(order_id: str, payment_id: str, amount: int, status: str) -> str:
    message = f"{order_id}:{payment_id}:{amount}:{status}"
    return hmac.new(
        settings.sandbox_payment_secret.encode(), message.encode(), hashlib.sha256
    ).hexdigest()


def verify_sandbox_signature(
    order_id: str, payment_id: str, amount: int, status: str, signature: str
) -> bool:
    return hmac.compare_digest(
        sandbox_signature(order_id, payment_id, amount, status), signature
    )


def razorpay_configured() -> bool:
    return bool(settings.razorpay_key_id and settings.razorpay_key_secret)


def available_methods() -> list[dict]:
    methods = [
        {"code": "cash", "label": "Cash", "enabled": True, "provider": "cash"},
        {"code": "mock_upi", "label": "Sandbox UPI", "enabled": settings.is_dev, "provider": "sandbox"},
    ]
    if razorpay_configured():
        methods.extend(
            [
                {"code": "upi", "label": "UPI", "enabled": True, "provider": "razorpay"},
                {"code": "card", "label": "Card", "enabled": True, "provider": "razorpay"},
            ]
        )
    wallet_balance = None
    return methods


def _find_payment(db: Session, user_id: str, ride_id: str, purpose: str) -> PaymentTransaction | None:
    return db.scalars(
        select(PaymentTransaction)
        .where(
            PaymentTransaction.user_id == user_id,
            PaymentTransaction.ride_request_id == ride_id,
            PaymentTransaction.purpose == purpose,
            PaymentTransaction.status.in_(["created", "pending", "captured"]),
        )
        .order_by(PaymentTransaction.created_at.desc())
    ).first()


def create_ride_payment(
    db: Session,
    user: User,
    ride_id: str,
    method: str,
    idempotency_key: str,
) -> PaymentTransaction:
    if method not in PAYABLE_METHODS:
        raise api_error(400, "payment_method_invalid", "Choose a valid payment method.")
    ride = db.scalar(
        select(RideRequest).where(
            RideRequest.id == ride_id, RideRequest.passenger_id == user.id
        )
    )
    if not ride or not ride.trip:
        raise api_error(404, "ride_not_found", "Ride not found.")
    trip = ride.trip
    if trip.state != "completed":
        raise api_error(409, "ride_not_completed", "Payment is available after the trip is completed.")
    if trip.payment_status == "paid":
        raise api_error(409, "already_paid", "This trip is already paid.")

    existing = db.scalar(
        select(PaymentTransaction).where(
            PaymentTransaction.user_id == user.id,
            PaymentTransaction.idempotency_key == idempotency_key,
            PaymentTransaction.purpose == "ride",
        )
    )
    if existing:
        return existing

    prior = _find_payment(db, user.id, ride.id, "ride")
    if prior and prior.status in {"created", "pending"} and prior.method == method:
        return prior

    amount = trip.final_fare_paise or ride.quoted_fare_paise
    if method in {"upi", "card"} and not razorpay_configured():
        raise api_error(
            503,
            "payment_provider_unconfigured",
            "Online card/UPI payments are not configured. Use cash or the clearly labelled sandbox UPI method.",
        )
    if method == "wallet":
        from app.services.ledger_service import balance_paise

        balance = balance_paise(db, "passenger_wallet", user.id)
        if balance < amount:
            raise api_error(
                402,
                "wallet_insufficient",
                "Your Neev wallet balance is too low for this trip.",
                {"balance_paise": balance},
            )

    provider = (
        "cash"
        if method == "cash"
        else ("sandbox" if method in {"mock_upi", "wallet"} else "razorpay")
    )
    payment = PaymentTransaction(
        ride_request_id=ride.id,
        trip_id=trip.id,
        user_id=user.id,
        purpose="ride",
        amount_paise=amount,
        method=method,
        provider=provider,
        status="pending" if method == "cash" else "created",
        idempotency_key=idempotency_key,
        metadata_json={"ride_id": ride.id},
    )
    db.add(payment)
    db.flush()

    if method == "mock_upi":
        payment.provider_order_id = f"sbx_order_{secrets.token_hex(10)}"
    elif method in {"upi", "card"}:
        order = _razorpay_create_order(payment.amount_paise, receipt=ride.id[:30])
        payment.provider_order_id = order["id"]
    elif method == "wallet":
        from app.services.ledger_service import payable_from_wallet

        payable_from_wallet(db, user.id, payment)
        payment.status = "captured"
        payment.captured_at = utcnow()
        payment.signature_verified = False
        finalize_payment(db, payment)
    trip.payment_method = method
    db.commit()
    return payment


def _razorpay_create_order(amount_paise: int, receipt: str) -> dict:
    if not razorpay_configured():
        raise api_error(503, "payment_provider_unconfigured", "Razorpay is not configured.")
    try:
        response = httpx.post(
            "https://api.razorpay.com/v1/orders",
            auth=(settings.razorpay_key_id, settings.razorpay_key_secret),
            json={
                "amount": amount_paise,
                "currency": "INR",
                "receipt": receipt,
                "payment_capture": 1,
            },
            timeout=10.0,
        )
        response.raise_for_status()
        return response.json()
    except Exception:
        logger.exception("razorpay.order_failed")
        raise api_error(502, "payment_provider_error", "The payment provider did not accept the order.")


def confirm_cash(db: Session, user: User, ride_id: str) -> PaymentTransaction:
    payment = _find_payment(db, user.id, ride_id, "ride")
    if not payment or payment.method != "cash":
        raise api_error(404, "payment_not_found", "No cash payment is pending for this ride.")
    if payment.status == "captured":
        return payment
    payment.status = "captured"
    payment.captured_at = utcnow()
    payment.signature_verified = False
    finalize_payment(db, payment)
    db.commit()
    return payment


def sandbox_confirm(
    db: Session, payment: PaymentTransaction, outcome: str
) -> PaymentTransaction:
    if not settings.is_dev or settings.payment_provider != "sandbox":
        raise api_error(403, "sandbox_disabled", "Sandbox payments are disabled in this environment.")
    if payment.provider not in {"sandbox"}:
        raise api_error(400, "not_sandbox", "This payment is not a sandbox payment.")
    if payment.status == "captured":
        return payment
    status = "captured" if outcome == "success" else "failed"
    payment.provider_payment_id = f"sbx_pay_{secrets.token_hex(10)}"
    signature = sandbox_signature(
        payment.provider_order_id or "", payment.provider_payment_id, payment.amount_paise, status
    )
    if not verify_sandbox_signature(
        payment.provider_order_id or "", payment.provider_payment_id, payment.amount_paise, status, signature
    ):
        raise api_error(400, "signature_invalid", "Payment signature verification failed.")
    payment.signature_verified = True
    payment.status = status
    if status == "captured":
        payment.captured_at = utcnow()
        finalize_payment(db, payment)
    else:
        payment.failure_reason = "Sandbox payment declined by test outcome"
    db.commit()
    return payment


def handle_razorpay_webhook(db: Session, raw_body: bytes, signature: str) -> PaymentTransaction | None:
    if not settings.razorpay_webhook_secret:
        raise api_error(503, "webhook_unconfigured", "Razorpay webhook secret is not configured.")
    expected = hmac.new(
        settings.razorpay_webhook_secret.encode(), raw_body, hashlib.sha256
    ).hexdigest()
    if not hmac.compare_digest(expected, signature):
        raise api_error(400, "signature_invalid", "Webhook signature verification failed.")
    import json

    payload = json.loads(raw_body)
    entity = payload.get("payload", {}).get("payment", {}).get("entity", {})
    order_id = entity.get("order_id")
    if not order_id:
        return None
    payment = db.scalar(
        select(PaymentTransaction).where(PaymentTransaction.provider_order_id == order_id)
    )
    if not payment:
        return None
    event = payload.get("event")
    if event == "payment.captured" and payment.status != "captured":
        payment.provider_payment_id = entity.get("id")
        payment.status = "captured"
        payment.captured_at = utcnow()
        payment.signature_verified = True
        finalize_payment(db, payment)
        db.commit()
    elif event == "payment.failed":
        payment.status = "failed"
        payment.failure_reason = entity.get("error_description", "Payment failed")
        db.commit()
    return payment


def finalize_payment(db: Session, payment: PaymentTransaction) -> None:
    if payment.purpose == "ride":
        trip = db.get(Trip, payment.trip_id) if payment.trip_id else None
        ride = db.get(RideRequest, payment.ride_request_id) if payment.ride_request_id else None
        if trip:
            trip.payment_status = "paid"
            trip.payment_method = payment.method
            if ride:
                commission = float((ride.fare_breakdown or {}).get("commission_pct", 20.0))
                post_trip_earnings(db, trip=trip, ride=ride, payment=payment, commission_pct=commission)
    elif payment.purpose == "power_pass":
        meta = payment.metadata_json or {}
        plan = db.get(PowerPassPlan, meta.get("plan_id"))
        if plan and not db.scalar(select(UserPowerPass).where(UserPowerPass.payment_id == payment.id)):
            start = utcnow()
            db.add(
                UserPowerPass(
                    user_id=payment.user_id,
                    plan_id=plan.id,
                    rides_total=plan.ride_limit,
                    rides_used=0,
                    starts_at=start,
                    expires_at=start + timedelta(days=plan.validity_days),
                    payment_id=payment.id,
                )
            )
    elif payment.purpose == "wallet_topup":
        post_wallet_topup(db, payment)


async def after_payment(db: Session, payment: PaymentTransaction) -> None:
    if payment.ride_request_id:
        ride = db.get(RideRequest, payment.ride_request_id)
        if ride:
            event = add_ride_event(
                db,
                ride=ride,
                event_type="payment.updated",
                payload={
                    "payment_id": payment.id,
                    "status": payment.status,
                    "method": payment.method,
                    "amount_paise": payment.amount_paise,
                },
            )
            db.commit()
            await manager.send_to_users(
                {ride.passenger_id, ride.assigned_captain_id},
                envelope(
                    "payment.updated",
                    ride.id,
                    {
                        "payment_id": payment.id,
                        "status": payment.status,
                        "method": payment.method,
                        "amount_paise": payment.amount_paise,
                        "sandbox": payment.provider == "sandbox",
                    },
                    event_id=event.id,
                ),
            )
            await notify_user(
                db,
                user_id=ride.passenger_id,
                notification_type="payment.updated",
                title="Payment successful" if payment.status == "captured" else "Payment failed",
                body=f"Your {payment.method.replace('_', ' ')} payment was {payment.status}.",
                data={"ride_id": ride.id, "payment_id": payment.id},
            )


def create_power_pass_payment(
    db: Session, user: User, plan_id: str, method: str, idempotency_key: str
) -> PaymentTransaction:
    plan = db.get(PowerPassPlan, plan_id)
    if not plan or not plan.is_active:
        raise api_error(404, "plan_not_found", "That Power Pass plan is unavailable.")
    existing = db.scalar(
        select(PaymentTransaction).where(
            PaymentTransaction.user_id == user.id,
            PaymentTransaction.idempotency_key == idempotency_key,
            PaymentTransaction.purpose == "power_pass",
        )
    )
    if existing:
        return existing
    if method not in {"mock_upi", "upi", "card", "wallet"}:
        raise api_error(400, "payment_method_invalid", "Power Pass requires a prepaid method.")
    if method in {"upi", "card"} and not razorpay_configured():
        raise api_error(503, "payment_provider_unconfigured", "Online payments are not configured.")
    provider = "sandbox" if method in {"mock_upi", "wallet"} else "razorpay"
    payment = PaymentTransaction(
        user_id=user.id,
        purpose="power_pass",
        amount_paise=plan.price_paise,
        method=method,
        provider=provider,
        status="created",
        idempotency_key=idempotency_key,
        metadata_json={"plan_id": plan.id, "plan_code": plan.code},
    )
    db.add(payment)
    db.flush()
    if method == "mock_upi":
        payment.provider_order_id = f"sbx_order_{secrets.token_hex(10)}"
    elif method in {"upi", "card"}:
        order = _razorpay_create_order(payment.amount_paise, receipt=f"pass-{plan.code}"[:30])
        payment.provider_order_id = order["id"]
    elif method == "wallet":
        from app.services.ledger_service import payable_from_wallet

        payable_from_wallet(db, user.id, payment)
        payment.status = "captured"
        payment.captured_at = utcnow()
        finalize_payment(db, payment)
    db.commit()
    return payment


def create_wallet_topup(
    db: Session, user: User, amount_paise: int, method: str, idempotency_key: str
) -> PaymentTransaction:
    if amount_paise < 10000 or amount_paise > 500000:
        raise api_error(400, "amount_invalid", "Top-up must be between ₹100 and ₹5,000.")
    existing = db.scalar(
        select(PaymentTransaction).where(
            PaymentTransaction.user_id == user.id,
            PaymentTransaction.idempotency_key == idempotency_key,
            PaymentTransaction.purpose == "wallet_topup",
        )
    )
    if existing:
        return existing
    if method not in {"mock_upi", "upi", "card"}:
        raise api_error(400, "payment_method_invalid", "Choose a supported top-up method.")
    if method in {"upi", "card"} and not razorpay_configured():
        raise api_error(503, "payment_provider_unconfigured", "Online payments are not configured.")
    provider = "sandbox" if method == "mock_upi" else "razorpay"
    payment = PaymentTransaction(
        user_id=user.id,
        purpose="wallet_topup",
        amount_paise=amount_paise,
        method=method,
        provider=provider,
        status="created",
        idempotency_key=idempotency_key,
        metadata_json={"sandbox": provider == "sandbox"},
    )
    db.add(payment)
    db.flush()
    if method == "mock_upi":
        payment.provider_order_id = f"sbx_order_{secrets.token_hex(10)}"
    else:
        order = _razorpay_create_order(amount_paise, receipt="wallet")
        payment.provider_order_id = order["id"]
    db.commit()
    return payment


def request_refund(db: Session, user: User, payment_id: str, reason: str):
    from app.models import Refund

    payment = db.get(PaymentTransaction, payment_id)
    if not payment or payment.user_id != user.id:
        raise api_error(404, "payment_not_found", "Payment not found.")
    if payment.status != "captured":
        raise api_error(409, "refund_not_allowed", "Only captured payments can be refunded.")
    existing = db.scalar(
        select(Refund).where(
            Refund.payment_id == payment.id,
            Refund.status.in_(["requested", "approved", "processed"]),
        )
    )
    if existing:
        return existing
    refund = Refund(
        payment_id=payment.id,
        user_id=user.id,
        ride_request_id=payment.ride_request_id,
        amount_paise=payment.amount_paise,
        reason=reason,
        status="requested",
    )
    db.add(refund)
    db.commit()
    return refund


def decide_refund(db: Session, refund, decision: str, note: str, admin_id: str):
    from app.models import LedgerEntry, Refund

    if refund.status in {"processed", "rejected"}:
        raise api_error(409, "refund_final", "This refund is already final.")
    if decision == "reject":
        refund.status = "rejected"
        refund.admin_id = admin_id
        refund.admin_note = note
        refund.processed_at = utcnow()
        db.commit()
        return refund

    payment = db.get(PaymentTransaction, refund.payment_id)
    if not payment:
        raise api_error(404, "payment_not_found", "Payment not found.")
    provider_refund_id = None
    if payment.provider == "razorpay":
        if not razorpay_configured():
            raise api_error(503, "payment_provider_unconfigured", "Razorpay is not configured.")
        try:
            response = httpx.post(
                f"https://api.razorpay.com/v1/payments/{payment.provider_payment_id}/refund",
                auth=(settings.razorpay_key_id, settings.razorpay_key_secret),
                json={"amount": refund.amount_paise, "notes": {"reason": note[:200]}},
                timeout=10.0,
            )
            response.raise_for_status()
            provider_refund_id = response.json().get("id")
        except Exception:
            logger.exception("razorpay.refund_failed")
            raise api_error(502, "refund_provider_error", "The payment provider rejected the refund.")
    else:
        provider_refund_id = f"sbx_refund_{secrets.token_hex(8)}"

    # Reverse the earnings and commission that were posted for this payment.
    entries = db.scalars(
        select(LedgerEntry).where(
            LedgerEntry.payment_id == payment.id,
            LedgerEntry.entry_type.in_(["trip_earning", "trip_commission"]),
        )
    ).all()
    for entry in entries:
        db.add(
            LedgerEntry(
                account_type=entry.account_type,
                user_id=entry.user_id,
                ride_request_id=entry.ride_request_id,
                payment_id=payment.id,
                entry_type="refund_reversal",
                amount_paise=-entry.amount_paise,
                description=f"Reversal for refund {refund.id}"[:240],
                metadata_json={"refund_id": refund.id, "original_entry": entry.id},
            )
        )
    if payment.method == "wallet":
        db.add(
            LedgerEntry(
                account_type="passenger_wallet",
                user_id=payment.user_id,
                payment_id=payment.id,
                entry_type="wallet_refund",
                amount_paise=refund.amount_paise,
                description="Wallet refund",
                metadata_json={"refund_id": refund.id},
            )
        )
    payment.status = "refunded"
    if payment.trip_id:
        trip = db.get(Trip, payment.trip_id)
        if trip:
            trip.payment_status = "refunded"
    refund.status = "processed"
    refund.admin_id = admin_id
    refund.admin_note = note
    refund.provider_refund_id = provider_refund_id
    refund.processed_at = utcnow()
    db.commit()
    return refund
