from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class PricingUpdate(BaseModel):
    base_fare_paise: int | None = Field(default=None, ge=0)
    minimum_fare_paise: int | None = Field(default=None, ge=0)
    per_km_paise: int | None = Field(default=None, ge=0)
    per_minute_paise: int | None = Field(default=None, ge=0)
    waiting_per_minute_paise: int | None = Field(default=None, ge=0)
    cancellation_fee_paise: int | None = Field(default=None, ge=0)
    platform_fee_paise: int | None = Field(default=None, ge=0)
    commission_pct: float | None = Field(default=None, ge=0, le=100)
    night_multiplier: float | None = Field(default=None, ge=0.5, le=5)
    is_active: bool | None = None


class PricingCreate(PricingUpdate):
    category: Literal["bike", "auto", "cab"]
    service_area_id: str | None = None
    base_fare_paise: int = Field(default=2500, ge=0)
    minimum_fare_paise: int = Field(default=4000, ge=0)
    per_km_paise: int = Field(default=1100, ge=0)
    per_minute_paise: int = Field(default=150, ge=0)


class CategoryUpdate(BaseModel):
    display_name: str | None = Field(default=None, max_length=60)
    description: str | None = Field(default=None, max_length=240)
    capacity: int | None = Field(default=None, ge=1, le=10)
    is_active: bool | None = None
    sort_order: int | None = None


class CouponCreate(BaseModel):
    code: str = Field(min_length=3, max_length=30)
    description: str = Field(min_length=3, max_length=240)
    discount_type: Literal["percent", "fixed"] = "percent"
    value: int = Field(ge=1)
    max_discount_paise: int | None = Field(default=None, ge=0)
    min_fare_paise: int = Field(default=0, ge=0)
    max_uses: int | None = Field(default=None, ge=1)
    per_user_limit: int = Field(default=1, ge=1)
    categories: list[str] | None = None
    valid_until: datetime
    is_active: bool = True


class CouponUpdate(BaseModel):
    description: str | None = Field(default=None, max_length=240)
    value: int | None = Field(default=None, ge=1)
    max_discount_paise: int | None = Field(default=None, ge=0)
    min_fare_paise: int | None = Field(default=None, ge=0)
    max_uses: int | None = Field(default=None, ge=1)
    per_user_limit: int | None = Field(default=None, ge=1)
    categories: list[str] | None = None
    valid_until: datetime | None = None
    is_active: bool | None = None


class PowerPassUpdate(BaseModel):
    name: str | None = Field(default=None, max_length=80)
    description: str | None = Field(default=None, max_length=240)
    price_paise: int | None = Field(default=None, ge=0)
    discount_pct: int | None = Field(default=None, ge=0, le=100)
    max_discount_paise: int | None = Field(default=None, ge=0)
    ride_limit: int | None = Field(default=None, ge=1, le=100)
    validity_days: int | None = Field(default=None, ge=1, le=365)
    is_active: bool | None = None


class ServiceAreaCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    city: str = Field(min_length=2, max_length=100)
    center_lat: float = Field(ge=-90, le=90)
    center_lng: float = Field(ge=-180, le=180)
    radius_km: float = Field(default=25, gt=0, le=200)
    is_active: bool = True


class ServiceAreaUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    city: str | None = Field(default=None, min_length=2, max_length=100)
    center_lat: float | None = Field(default=None, ge=-90, le=90)
    center_lng: float | None = Field(default=None, ge=-180, le=180)
    radius_km: float | None = Field(default=None, gt=0, le=200)
    is_active: bool | None = None


class TicketResolve(BaseModel):
    resolution_notes: str = Field(min_length=3, max_length=4000)
    status: Literal["pending", "resolved", "closed"] = "resolved"


class RefundDecision(BaseModel):
    decision: Literal["approve", "reject"]
    note: str = Field(min_length=3, max_length=2000)


class PayoutDecision(BaseModel):
    decision: Literal["approve", "reject", "complete", "fail"]
    note: str | None = Field(default=None, max_length=1000)
    provider_reference: str | None = Field(default=None, max_length=120)


class SettingUpdate(BaseModel):
    value: dict
    description: str | None = Field(default=None, max_length=300)


class AdminCreate(BaseModel):
    email: str = Field(min_length=3, max_length=200)
    name: str = Field(min_length=2, max_length=120)
    password: str = Field(min_length=12, max_length=200)
    role: Literal["super_admin", "admin", "support"] = "support"
