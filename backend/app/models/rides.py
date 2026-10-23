from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base, new_uuid, utcnow


class RideRequest(Base):
    __tablename__ = "ride_requests"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    passenger_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    category: Mapped[str] = mapped_column(String(20), index=True)
    pickup_lat: Mapped[float] = mapped_column()
    pickup_lng: Mapped[float] = mapped_column()
    pickup_address: Mapped[str] = mapped_column(String(300))
    drop_lat: Mapped[float] = mapped_column()
    drop_lng: Mapped[float] = mapped_column()
    drop_address: Mapped[str] = mapped_column(String(300))
    distance_m: Mapped[int] = mapped_column(Integer)
    duration_s: Mapped[int] = mapped_column(Integer)
    fare_estimate_id: Mapped[str | None] = mapped_column(String(36))
    quoted_fare_paise: Mapped[int] = mapped_column(Integer)
    fare_breakdown: Mapped[dict] = mapped_column(JSON)
    route_points: Mapped[list | None] = mapped_column(JSON)
    pricing_version: Mapped[int] = mapped_column(Integer)
    coupon_id: Mapped[str | None] = mapped_column(String(36))
    discount_paise: Mapped[int] = mapped_column(Integer, default=0)
    power_pass_id: Mapped[str | None] = mapped_column(String(36))
    payment_method: Mapped[str] = mapped_column(String(20), default="cash")
    status: Mapped[str] = mapped_column(String(24), default="searching", index=True)
    assigned_captain_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    assigned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_by: Mapped[str | None] = mapped_column(String(20))
    cancellation_reason: Mapped[str | None] = mapped_column(Text)
    cancellation_fee_paise: Mapped[int] = mapped_column(Integer, default=0)
    idempotency_key: Mapped[str | None] = mapped_column(String(80))
    request_ip: Mapped[str | None] = mapped_column(String(64))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    version: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )

    trip: Mapped[Trip | None] = relationship(back_populates="ride", uselist=False)

    __table_args__ = (
        UniqueConstraint(
            "passenger_id", "idempotency_key", name="uq_ride_passenger_idempotency"
        ),
        Index("ix_ride_status_created", "status", "created_at"),
    )


class RideAssignment(Base):
    __tablename__ = "ride_assignments"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    ride_request_id: Mapped[str] = mapped_column(
        ForeignKey("ride_requests.id", ondelete="CASCADE"), index=True
    )
    captain_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    status: Mapped[str] = mapped_column(String(20), default="offered", index=True)
    distance_m: Mapped[int | None] = mapped_column(Integer)
    offered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        UniqueConstraint("ride_request_id", "captain_id", name="uq_ride_captain_offer"),
    )


class Trip(Base):
    __tablename__ = "trips"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    ride_request_id: Mapped[str] = mapped_column(
        ForeignKey("ride_requests.id", ondelete="CASCADE"), unique=True, index=True
    )
    passenger_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    captain_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    vehicle_id: Mapped[str | None] = mapped_column(String(36))
    state: Mapped[str] = mapped_column(String(24), default="captain_arriving", index=True)
    start_pin_hash: Mapped[str] = mapped_column(String(128))
    start_pin_enc: Mapped[str] = mapped_column(String(300))
    pin_expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    pin_attempts: Mapped[int] = mapped_column(Integer, default=0)
    pin_locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    accepted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    arrived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_by: Mapped[str | None] = mapped_column(String(20))
    cancel_reason: Mapped[str | None] = mapped_column(Text)
    final_fare_paise: Mapped[int | None] = mapped_column(Integer)
    fare_breakdown: Mapped[dict | None] = mapped_column(JSON)
    payment_status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
    payment_method: Mapped[str | None] = mapped_column(String(20))
    distance_m: Mapped[int | None] = mapped_column(Integer)
    duration_s: Mapped[int | None] = mapped_column(Integer)
    completed_lat: Mapped[float | None] = mapped_column()
    completed_lng: Mapped[float | None] = mapped_column()
    drop_verified: Mapped[bool | None] = mapped_column()
    version: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )

    ride: Mapped[RideRequest] = relationship(back_populates="trip")


class RideEvent(Base):
    __tablename__ = "ride_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ride_request_id: Mapped[str] = mapped_column(
        ForeignKey("ride_requests.id", ondelete="CASCADE"), index=True
    )
    trip_id: Mapped[str | None] = mapped_column(String(36), index=True)
    event_type: Mapped[str] = mapped_column(String(50), index=True)
    actor_user_id: Mapped[str | None] = mapped_column(String(36))
    payload: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)

    __table_args__ = (Index("ix_ride_event_ride_seq", "ride_request_id", "id"),)


class LocationUpdate(Base):
    __tablename__ = "location_updates"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    trip_id: Mapped[str] = mapped_column(
        ForeignKey("trips.id", ondelete="CASCADE"), index=True
    )
    captain_id: Mapped[str] = mapped_column(String(36), index=True)
    lat: Mapped[float] = mapped_column()
    lng: Mapped[float] = mapped_column()
    accuracy_m: Mapped[float | None] = mapped_column()
    speed_mps: Mapped[float | None] = mapped_column()
    heading: Mapped[float | None] = mapped_column()
    source: Mapped[str] = mapped_column(String(20), default="gps")
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    __table_args__ = (Index("ix_location_trip_time", "trip_id", "recorded_at"),)


class OutboxMessage(Base):
    __tablename__ = "outbox_messages"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    channel: Mapped[str] = mapped_column(String(20), default="sms")
    recipient: Mapped[str] = mapped_column(String(40))
    template: Mapped[str] = mapped_column(String(60))
    body: Mapped[str] = mapped_column(Text)
    provider: Mapped[str] = mapped_column(String(30))
    status: Mapped[str] = mapped_column(String(20), default="simulated", index=True)
    provider_message_id: Mapped[str | None] = mapped_column(String(100))
    error: Mapped[str | None] = mapped_column(String(300))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
