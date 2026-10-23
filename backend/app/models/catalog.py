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
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base, new_uuid, utcnow
from app.models.captains import ServiceArea


class ServiceCategory(Base):
    __tablename__ = "service_categories"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    code: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    display_name: Mapped[str] = mapped_column(String(60))
    description: Mapped[str] = mapped_column(String(240))
    capacity: Mapped[int] = mapped_column(Integer, default=1)
    icon: Mapped[str] = mapped_column(String(40), default="bike")
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class PricingRule(Base):
    __tablename__ = "pricing_rules"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    category: Mapped[str] = mapped_column(String(20), index=True)
    service_area_id: Mapped[str | None] = mapped_column(
        ForeignKey("service_areas.id", ondelete="SET NULL"), index=True
    )
    base_fare_paise: Mapped[int] = mapped_column(Integer, default=2500)
    minimum_fare_paise: Mapped[int] = mapped_column(Integer, default=4000)
    per_km_paise: Mapped[int] = mapped_column(Integer, default=1100)
    per_minute_paise: Mapped[int] = mapped_column(Integer, default=150)
    waiting_per_minute_paise: Mapped[int] = mapped_column(Integer, default=200)
    cancellation_fee_paise: Mapped[int] = mapped_column(Integer, default=2000)
    platform_fee_paise: Mapped[int] = mapped_column(Integer, default=500)
    commission_pct: Mapped[float] = mapped_column(default=20.0)
    night_multiplier: Mapped[float] = mapped_column(default=1.0)
    version: Mapped[int] = mapped_column(Integer, default=1)
    currency: Mapped[str] = mapped_column(String(3), default="INR")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    effective_from: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )

    service_area: Mapped[ServiceArea | None] = relationship()


class Coupon(Base):
    __tablename__ = "coupons"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    code: Mapped[str] = mapped_column(String(30), unique=True, index=True)
    description: Mapped[str] = mapped_column(String(240))
    discount_type: Mapped[str] = mapped_column(String(12), default="percent")
    value: Mapped[int] = mapped_column(Integer)
    max_discount_paise: Mapped[int | None] = mapped_column(Integer)
    min_fare_paise: Mapped[int] = mapped_column(Integer, default=0)
    max_uses: Mapped[int | None] = mapped_column(Integer)
    per_user_limit: Mapped[int] = mapped_column(Integer, default=1)
    used_count: Mapped[int] = mapped_column(Integer, default=0)
    categories: Mapped[list | None] = mapped_column(JSON)
    valid_from: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    valid_until: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class CouponRedemption(Base):
    __tablename__ = "coupon_redemptions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    coupon_id: Mapped[str] = mapped_column(
        ForeignKey("coupons.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    ride_request_id: Mapped[str | None] = mapped_column(String(36), index=True)
    discount_paise: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    __table_args__ = (
        UniqueConstraint("coupon_id", "ride_request_id", name="uq_coupon_ride"),
    )


class PowerPassPlan(Base):
    __tablename__ = "power_pass_plans"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    code: Mapped[str] = mapped_column(String(30), unique=True)
    name: Mapped[str] = mapped_column(String(80))
    description: Mapped[str] = mapped_column(String(240))
    price_paise: Mapped[int] = mapped_column(Integer)
    discount_pct: Mapped[int] = mapped_column(Integer)
    max_discount_paise: Mapped[int | None] = mapped_column(Integer)
    ride_limit: Mapped[int] = mapped_column(Integer)
    validity_days: Mapped[int] = mapped_column(Integer)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class UserPowerPass(Base):
    __tablename__ = "user_power_passes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    plan_id: Mapped[str] = mapped_column(ForeignKey("power_pass_plans.id"))
    rides_total: Mapped[int] = mapped_column(Integer)
    rides_used: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(20), default="active", index=True)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    payment_id: Mapped[str | None] = mapped_column(String(36))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    plan: Mapped[PowerPassPlan] = relationship()

    __table_args__ = (Index("ix_power_pass_user_status", "user_id", "status"),)


class FareEstimate(Base):
    __tablename__ = "fare_estimates"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    category: Mapped[str] = mapped_column(String(20))
    pickup_lat: Mapped[float] = mapped_column()
    pickup_lng: Mapped[float] = mapped_column()
    drop_lat: Mapped[float] = mapped_column()
    drop_lng: Mapped[float] = mapped_column()
    pickup_address: Mapped[str] = mapped_column(String(300))
    drop_address: Mapped[str] = mapped_column(String(300))
    distance_m: Mapped[int] = mapped_column(Integer)
    duration_s: Mapped[int] = mapped_column(Integer)
    total_paise: Mapped[int] = mapped_column(Integer)
    breakdown: Mapped[dict] = mapped_column(JSON)
    pricing_version: Mapped[int] = mapped_column(Integer)
    coupon_code: Mapped[str | None] = mapped_column(String(30))
    power_pass_id: Mapped[str | None] = mapped_column(String(36))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
