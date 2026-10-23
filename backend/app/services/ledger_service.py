from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import api_error
from app.models import CaptainProfile, LedgerEntry, PaymentTransaction, PayoutRequest, RideRequest, Trip, User


def balance_paise(db: Session, account_type: str, user_id: str | None = None) -> int:
    stmt = select(func.coalesce(func.sum(LedgerEntry.amount_paise), 0)).where(
        LedgerEntry.account_type == account_type
    )
    if user_id:
        stmt = stmt.where(LedgerEntry.user_id == user_id)
    return int(db.scalar(stmt) or 0)


def captain_available_paise(db: Session, captain_id: str) -> int:
    return balance_paise(db, "captain_earnings", captain_id)


def post_trip_earnings(
    db: Session,
    *,
    trip: Trip,
    ride: RideRequest,
    payment: PaymentTransaction,
    commission_pct: float,
) -> None:
    existing = db.scalar(
        select(LedgerEntry).where(
            LedgerEntry.payment_id == payment.id,
            LedgerEntry.entry_type == "trip_earning",
        )
    )
    if existing:
        return
    fare = trip.final_fare_paise or ride.quoted_fare_paise
    commission = int(round(fare * commission_pct / 100))
    captain_net = fare - commission
    base = {
        "ride_request_id": ride.id,
        "payment_id": payment.id,
        "metadata_json": {"trip_id": trip.id, "gross_paise": fare, "commission_pct": commission_pct},
    }
    db.add(
        LedgerEntry(
            account_type="captain_earnings",
            user_id=trip.captain_id,
            entry_type="trip_earning",
            amount_paise=captain_net,
            description=f"Trip earnings after {commission_pct:g}% platform commission",
            **base,
        )
    )
    db.add(
        LedgerEntry(
            account_type="platform_commission",
            user_id=None,
            entry_type="trip_commission",
            amount_paise=commission,
            description="Platform commission on a completed trip",
            **base,
        )
    )


def post_wallet_topup(db: Session, payment: PaymentTransaction) -> None:
    existing = db.scalar(
        select(LedgerEntry).where(
            LedgerEntry.payment_id == payment.id,
            LedgerEntry.entry_type == "wallet_topup",
        )
    )
    if existing:
        return
    db.add(
        LedgerEntry(
            account_type="passenger_wallet",
            user_id=payment.user_id,
            payment_id=payment.id,
            entry_type="wallet_topup",
            amount_paise=payment.amount_paise,
            description="Sandbox wallet top-up",
            metadata_json={"sandbox": True},
        )
    )


def request_payout(db: Session, captain_id: str, amount_paise: int, method: str, destination: str) -> PayoutRequest:
    profile = db.get(CaptainProfile, captain_id)
    if not profile:
        raise api_error(409, "onboarding_required", "Complete captain onboarding first.")
    available = captain_available_paise(db, captain_id)
    pending = db.scalar(
        select(func.coalesce(func.sum(PayoutRequest.amount_paise), 0)).where(
            PayoutRequest.captain_id == captain_id,
            PayoutRequest.status.in_(["requested", "approved", "processing"]),
        )
    ) or 0
    if amount_paise > available - pending:
        raise api_error(
            400,
            "insufficient_balance",
            "That amount is more than your available earnings.",
            {"available_paise": max(0, available - pending), "available_display": f"₹{max(0, available - pending) / 100:.2f}"},
        )
    masked = destination
    if method == "upi" and "@" in destination:
        local, domain = destination.split("@", 1)
        masked = local[:2] + "***@" + domain
    elif len(destination) > 4:
        masked = "***" + destination[-4:]
    payout = PayoutRequest(
        captain_id=captain_id,
        amount_paise=amount_paise,
        method=method,
        destination_masked=masked,
        status="requested",
    )
    db.add(payout)
    db.flush()
    # Hold the amount immediately so it cannot be requested twice.
    db.add(
        LedgerEntry(
            account_type="captain_earnings",
            user_id=captain_id,
            payout_id=payout.id,
            entry_type="payout_hold",
            amount_paise=-amount_paise,
            description="Payout requested — funds on hold",
        )
    )
    db.commit()
    return payout


def payable_from_wallet(db: Session, user_id: str, payment: PaymentTransaction) -> None:
    available = balance_paise(db, "passenger_wallet", user_id)
    if available < payment.amount_paise:
        raise api_error(
            402,
            "wallet_insufficient",
            "Your Neev wallet balance is too low for this trip.",
            {"balance_paise": available},
        )
    db.add(
        LedgerEntry(
            account_type="passenger_wallet",
            user_id=user_id,
            payment_id=payment.id,
            ride_request_id=payment.ride_request_id,
            entry_type="wallet_payment",
            amount_paise=-payment.amount_paise,
            description="Ride paid from Neev wallet",
        )
    )


def reverse_payout_hold(db: Session, payout: PayoutRequest) -> None:
    exists = db.scalar(
        select(LedgerEntry).where(
            LedgerEntry.payout_id == payout.id,
            LedgerEntry.entry_type == "payout_reversal",
        )
    )
    if exists:
        return
    db.add(
        LedgerEntry(
            account_type="captain_earnings",
            user_id=payout.captain_id,
            payout_id=payout.id,
            entry_type="payout_reversal",
            amount_paise=payout.amount_paise,
            description=f"Payout {payout.status} — funds returned",
        )
    )
