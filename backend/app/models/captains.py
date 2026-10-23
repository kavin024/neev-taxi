from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base, new_uuid, utcnow
from app.models.users import User


class CaptainProfile(Base):
    __tablename__ = "captain_profiles"

    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    name: Mapped[str] = mapped_column(String(120), default="Neev captain")
    email: Mapped[str | None] = mapped_column(String(200))
    photo_url: Mapped[str | None] = mapped_column(String(500))
    verification_status: Mapped[str] = mapped_column(
        String(20), default="pending", index=True
    )  # pending | approved | rejected | suspended
    rejection_reason: Mapped[str | None] = mapped_column(Text)
    dl_masked: Mapped[str | None] = mapped_column(String(40))
    pan_masked: Mapped[str | None] = mapped_column(String(20))
    aadhaar_masked: Mapped[str | None] = mapped_column(String(20))
    is_online: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    online_since: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_lat: Mapped[float | None] = mapped_column()
    last_lng: Mapped[float | None] = mapped_column()
    last_location_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_location_source: Mapped[str] = mapped_column(String(20), default="gps")
    service_area_id: Mapped[str | None] = mapped_column(
        ForeignKey("service_areas.id", ondelete="SET NULL")
    )
    total_trips: Mapped[int] = mapped_column(Integer, default=0)
    rating_sum: Mapped[int] = mapped_column(Integer, default=0)
    rating_count: Mapped[int] = mapped_column(Integer, default=0)
    payout_upi: Mapped[str | None] = mapped_column(String(120))
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    approved_by: Mapped[str | None] = mapped_column(String(36))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )

    user: Mapped[User] = relationship(back_populates="captain_profile")
    vehicles: Mapped[list[Vehicle]] = relationship(
        back_populates="captain", cascade="all, delete-orphan"
    )
    documents: Mapped[list[CaptainDocument]] = relationship(
        back_populates="captain", cascade="all, delete-orphan"
    )

    @property
    def rating(self) -> float | None:
        if not self.rating_count:
            return None
        return round(self.rating_sum / self.rating_count, 2)


class Vehicle(Base):
    __tablename__ = "vehicles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    captain_id: Mapped[str] = mapped_column(
        ForeignKey("captain_profiles.user_id", ondelete="CASCADE"), index=True
    )
    category: Mapped[str] = mapped_column(String(20), index=True)
    reg_number: Mapped[str] = mapped_column(String(24), unique=True)
    make_model: Mapped[str] = mapped_column(String(120))
    color: Mapped[str | None] = mapped_column(String(40))
    year: Mapped[int | None] = mapped_column(Integer)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    captain: Mapped[CaptainProfile] = relationship(back_populates="vehicles")


class CaptainDocument(Base):
    __tablename__ = "captain_documents"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    captain_id: Mapped[str] = mapped_column(
        ForeignKey("captain_profiles.user_id", ondelete="CASCADE"), index=True
    )
    doc_type: Mapped[str] = mapped_column(String(40), index=True)
    storage_key: Mapped[str] = mapped_column(String(300), unique=True)
    original_filename: Mapped[str] = mapped_column(String(200))
    mime_type: Mapped[str] = mapped_column(String(80))
    size_bytes: Mapped[int] = mapped_column(Integer)
    checksum: Mapped[str] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text)
    reviewed_by: Mapped[str | None] = mapped_column(String(36))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    captain: Mapped[CaptainProfile] = relationship(back_populates="documents")


class CaptainLocation(Base):
    __tablename__ = "captain_locations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    captain_id: Mapped[str] = mapped_column(
        ForeignKey("captain_profiles.user_id", ondelete="CASCADE"), index=True
    )
    lat: Mapped[float] = mapped_column()
    lng: Mapped[float] = mapped_column()
    accuracy_m: Mapped[float | None] = mapped_column()
    source: Mapped[str] = mapped_column(String(20), default="gps")
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    __table_args__ = (Index("ix_captain_location_captain_time", "captain_id", "recorded_at"),)


class ServiceArea(Base):
    __tablename__ = "service_areas"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    name: Mapped[str] = mapped_column(String(120))
    city: Mapped[str] = mapped_column(String(100), index=True)
    center_lat: Mapped[float] = mapped_column()
    center_lng: Mapped[float] = mapped_column()
    radius_km: Mapped[float] = mapped_column(default=25.0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )
