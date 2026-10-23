from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

from app.schemas.common import ApiModel, PhoneStr, UserOut


class OtpRequestBody(BaseModel):
    phone: PhoneStr
    role: Literal["passenger", "captain"] = "passenger"


class OtpRequestOut(BaseModel):
    challenge_id: str
    phone: str
    expires_in: int
    resend_after: int
    dev_otp: str | None = None
    delivery: str


class OtpVerifyBody(BaseModel):
    phone: PhoneStr
    code: str = Field(min_length=4, max_length=8, pattern=r"^\d+$")
    role: Literal["passenger", "captain"] = "passenger"
    device_id: str | None = Field(default=None, max_length=120)


class RefreshBody(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=300)


class LogoutBody(BaseModel):
    refresh_token: str | None = Field(default=None, max_length=300)


class PassengerProfileUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    email: str | None = Field(default=None, max_length=200)
    photo_url: str | None = Field(default=None, max_length=500)
    home_area: str | None = Field(default=None, max_length=160)


class SavedAddressBody(BaseModel):
    label: str = Field(min_length=1, max_length=60)
    address: str = Field(min_length=3, max_length=300)
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)


class TrustedContactBody(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    phone: PhoneStr
    relationship: str | None = Field(default=None, max_length=60)


class CaptainProfileUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    email: str | None = Field(default=None, max_length=200)
    payout_upi: str | None = Field(default=None, max_length=120)


class VehicleBody(BaseModel):
    category: Literal["bike", "auto", "cab"]
    reg_number: str = Field(min_length=4, max_length=24)
    make_model: str = Field(min_length=2, max_length=120)
    color: str | None = Field(default=None, max_length=40)
    year: int | None = Field(default=None, ge=1990, le=2100)

    @field_validator("reg_number")
    @classmethod
    def _upper(cls, value: str) -> str:
        return value.upper().replace(" ", "")


class OnlineBody(BaseModel):
    is_online: bool
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)


class CaptainDraftBody(BaseModel):
    """Initial captain onboarding details; documents are uploaded separately."""

    name: str = Field(min_length=2, max_length=120)
    email: str | None = Field(default=None, max_length=200)
    service_area_id: str | None = None
    dl_number: str = Field(min_length=4, max_length=30)
    pan_number: str | None = Field(default=None, min_length=10, max_length=10)
    aadhaar_last4: str | None = Field(default=None, min_length=4, max_length=4)


class AdminLoginBody(BaseModel):
    email: str = Field(min_length=3, max_length=200)
    password: str = Field(min_length=8, max_length=200)


class CaptainDecisionBody(BaseModel):
    approved: bool
    reason: str | None = Field(default=None, max_length=1000)


class SuspendBody(BaseModel):
    suspended: bool = True
    reason: str = Field(min_length=3, max_length=1000)


class AdminUserOut(ApiModel):
    id: str
    email: str
    name: str
    role: str
    is_active: bool
    last_login_at: datetime | None


class OtpChallengeOut(ApiModel):
    id: str
    phone: str
    purpose: str
    attempts: int
    expires_at: datetime


class UserMe(UserOut):
    pass
