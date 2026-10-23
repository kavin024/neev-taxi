from __future__ import annotations

import re
from datetime import datetime
from typing import Annotated, Any, Literal

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, field_validator


def normalize_phone(value: str) -> str:
    digits = re.sub(r"[^\d+]", "", value.strip())
    if digits.startswith("+91") and len(digits) == 13:
        return digits
    if digits.startswith("91") and len(digits) == 12:
        return "+" + digits
    if len(digits) == 10 and digits[0] in "6789":
        return "+91" + digits
    raise ValueError("Enter a valid Indian mobile number")


PhoneStr = Annotated[str, AfterValidator(normalize_phone)]


class ApiModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class LocationIn(ApiModel):
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    address: str = Field(min_length=3, max_length=300)


class Message(ApiModel):
    message: str


class Page(ApiModel):
    items: list[Any]
    total: int
    page: int
    page_size: int


class UserBrief(ApiModel):
    id: str
    phone: str
    role: str
    status: str
    is_demo: bool
    name: str | None = None
    photo_url: str | None = None


class UserOut(UserBrief):
    phone_verified: bool
    created_at: datetime
    passenger: dict | None = None
    captain: dict | None = None


class TokenPair(ApiModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int
    user: UserOut


class AdminToken(ApiModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int
    admin: dict


class ErrorBody(ApiModel):
    code: str
    message: str
    details: Any | None = None


class ErrorResponse(ApiModel):
    error: ErrorBody
    request_id: str | None = None


class TripPinOut(ApiModel):
    pin: str
    expires_at: datetime


class Money(ApiModel):
    amount_paise: int
    display: str


class Coordinates(ApiModel):
    lat: float
    lng: float

    @field_validator("lat")
    @classmethod
    def _lat(cls, v: float) -> float:
        if not -90 <= v <= 90:
            raise ValueError("latitude out of range")
        return v

    @field_validator("lng")
    @classmethod
    def _lng(cls, v: float) -> float:
        if not -180 <= v <= 180:
            raise ValueError("longitude out of range")
        return v
