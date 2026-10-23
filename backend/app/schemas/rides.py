from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, model_validator

from app.schemas.common import ApiModel, LocationIn


class QuoteBody(BaseModel):
    category: Literal["bike", "auto", "cab"]
    pickup: LocationIn
    drop: LocationIn
    coupon_code: str | None = Field(default=None, max_length=30)
    use_power_pass: bool = True

    @model_validator(mode="after")
    def _distinct(self):
        if (
            abs(self.pickup.lat - self.drop.lat) < 1e-6
            and abs(self.pickup.lng - self.drop.lng) < 1e-6
        ):
            raise ValueError("Pickup and drop must be different")
        return self


class FareLine(ApiModel):
    label: str
    amount_paise: int


class QuoteOut(ApiModel):
    category: str
    distance_m: int
    duration_s: int
    total_paise: int
    total_display: str
    lines: list[FareLine]
    coupon_code: str | None = None
    discount_paise: int = 0
    power_pass_applied: bool = False
    power_pass_id: str | None = None
    surge_multiplier: float = 1.0
    pricing_version: int
    quote_token: str
    expires_at: datetime
    currency: str = "INR"
    route_points: list[list[float]] = Field(default_factory=list)
    approximate_route: bool = True
    route_provider: str = "demo"


class RideRequestBody(BaseModel):
    category: Literal["bike", "auto", "cab"]
    pickup: LocationIn
    drop: LocationIn
    coupon_code: str | None = Field(default=None, max_length=30)
    use_power_pass: bool = True
    idempotency_key: str = Field(min_length=8, max_length=80)
    payment_method: Literal["cash", "mock_upi", "upi", "card", "wallet"] = "cash"
    quote_token: str | None = None


class RideCancelBody(BaseModel):
    reason: str = Field(min_length=3, max_length=500)
    accept_cancellation_fee: bool = False


class TripStartBody(BaseModel):
    pin: str = Field(min_length=4, max_length=4, pattern=r"^\d{4}$")


class LocationUpdateBody(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    accuracy_m: float | None = Field(default=None, ge=0, le=5000)
    speed_mps: float | None = Field(default=None, ge=0, le=120)
    heading: float | None = Field(default=None, ge=0, le=360)
    recorded_at: datetime
    source: Literal["gps", "simulated"] = "gps"


class TripCompleteBody(BaseModel):
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)


class RatingBody(BaseModel):
    stars: int = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=1000)
    tags: list[str] = Field(default_factory=list, max_length=8)


class PaymentCreateBody(BaseModel):
    method: Literal["cash", "mock_upi", "upi", "card", "wallet"]
    idempotency_key: str = Field(min_length=8, max_length=100)


class MockPaymentConfirmBody(BaseModel):
    outcome: Literal["success", "failure"] = "success"
    idempotency_key: str = Field(min_length=8, max_length=100)


class RefundRequestBody(BaseModel):
    reason: str = Field(min_length=5, max_length=1000)


class SupportTicketBody(BaseModel):
    category: Literal["payment", "cancellation", "safety", "driver", "app", "other"] = "other"
    subject: str = Field(min_length=3, max_length=200)
    description: str = Field(min_length=5, max_length=4000)
    ride_request_id: str | None = None


class TicketReplyBody(BaseModel):
    body: str = Field(min_length=1, max_length=4000)


class SosBody(BaseModel):
    ride_request_id: str | None = None
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)
    press_hold_ms: int = Field(ge=0, le=10000)
    note: str | None = Field(default=None, max_length=500)


class ShareTripBody(BaseModel):
    duration_minutes: int = Field(default=240, ge=5, le=720)


class PayoutRequestBody(BaseModel):
    amount_paise: int = Field(ge=10000, le=10_000_000)
    method: Literal["upi", "bank"] = "upi"
    destination: str = Field(min_length=3, max_length=120)


class NotificationReadBody(BaseModel):
    notification_ids: list[str] = Field(default_factory=list, max_length=100)
