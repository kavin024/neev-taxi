from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base, new_uuid, utcnow


class PaymentTransaction(Base):
    __tablename__ = "payment_transactions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    ride_request_id: Mapped[str | None] = mapped_column(
        ForeignKey("ride_requests.id", ondelete="SET NULL"), index=True
    )
    trip_id: Mapped[str | None] = mapped_column(String(36), index=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    purpose: Mapped[str] = mapped_column(String(30), default="ride")
    amount_paise: Mapped[int] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(String(3), default="INR")
    method: Mapped[str] = mapped_column(String(20))
    provider: Mapped[str] = mapped_column(String(20))
    provider_order_id: Mapped[str | None] = mapped_column(String(120), unique=True)
    provider_payment_id: Mapped[str | None] = mapped_column(String(120), unique=True)
    status: Mapped[str] = mapped_column(String(20), default="created", index=True)
    failure_reason: Mapped[str | None] = mapped_column(String(300))
    signature_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    idempotency_key: Mapped[str | None] = mapped_column(String(100), index=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )
    captured_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (Index("ix_payment_user_created", "user_id", "created_at"),)


class Refund(Base):
    __tablename__ = "refunds"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    payment_id: Mapped[str] = mapped_column(
        ForeignKey("payment_transactions.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    ride_request_id: Mapped[str | None] = mapped_column(String(36))
    amount_paise: Mapped[int] = mapped_column(Integer)
    reason: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), default="requested", index=True)
    admin_id: Mapped[str | None] = mapped_column(String(36))
    admin_note: Mapped[str | None] = mapped_column(Text)
    provider_refund_id: Mapped[str | None] = mapped_column(String(120))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class LedgerEntry(Base):
    __tablename__ = "ledger_entries"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    account_type: Mapped[str] = mapped_column(String(30), index=True)
    user_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    ride_request_id: Mapped[str | None] = mapped_column(String(36), index=True)
    payment_id: Mapped[str | None] = mapped_column(String(36))
    payout_id: Mapped[str | None] = mapped_column(String(36))
    entry_type: Mapped[str] = mapped_column(String(40))
    amount_paise: Mapped[int] = mapped_column(Integer)
    description: Mapped[str] = mapped_column(String(240))
    metadata_json: Mapped[dict | None] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)

    __table_args__ = (
        Index("ix_ledger_account_user", "account_type", "user_id"),
        Index("ix_ledger_ref", "payment_id", "entry_type"),
    )


class PayoutRequest(Base):
    __tablename__ = "payout_requests"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    captain_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    amount_paise: Mapped[int] = mapped_column(Integer)
    method: Mapped[str] = mapped_column(String(20), default="upi")
    destination_masked: Mapped[str] = mapped_column(String(120))
    status: Mapped[str] = mapped_column(String(20), default="requested", index=True)
    admin_id: Mapped[str | None] = mapped_column(String(36))
    admin_note: Mapped[str | None] = mapped_column(Text)
    provider_reference: Mapped[str | None] = mapped_column(String(120))
    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )
