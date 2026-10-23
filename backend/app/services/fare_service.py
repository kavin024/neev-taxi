from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import jwt
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import utcnow
from app.core.security import decode_token
from app.models import (
    Coupon,
    CouponRedemption,
    FareEstimate,
    PowerPassPlan,
    PricingRule,
    ServiceArea,
    ServiceCategory,
    User,
    UserPowerPass,
)
from app.services.geo import point_in_service_area
from app.services.maps import route_between

logger = logging.getLogger("neev.fare")

IST = ZoneInfo("Asia/Kolkata")


class FareError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 422, details=None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.details = details


@dataclass
class FareQuote:
    category: str
    distance_m: int
    duration_s: int
    total_paise: int
    lines: list[dict]
    pricing_version: int
    coupon: Coupon | None = None
    coupon_code: str | None = None
    coupon_discount_paise: int = 0
    power_pass: UserPowerPass | None = None
    power_pass_discount_paise: int = 0
    service_area: ServiceArea | None = None
    route_points: list[tuple[float, float]] = field(default_factory=list)
    approximate_route: bool = True
    route_provider: str = "demo"
    surge_multiplier: float = 1.0
    raw_subtotal_paise: int = 0


def _night_multiplier(now: datetime | None = None) -> float:
    local = (now or utcnow()).astimezone(IST)
    return 1.15 if local.hour >= 22 or local.hour < 6 else 1.0


def active_service_area(db: Session, lat: float, lng: float) -> ServiceArea | None:
    areas = db.scalars(select(ServiceArea).where(ServiceArea.is_active.is_(True))).all()
    for area in areas:
        if point_in_service_area(lat, lng, area):
            return area
    return None


def get_pricing_rule(
    db: Session, category: str, service_area_id: str | None
) -> PricingRule:
    stmt = (
        select(PricingRule)
        .where(PricingRule.category == category, PricingRule.is_active.is_(True))
        .order_by(PricingRule.service_area_id.is_(None), PricingRule.effective_from.desc())
    )
    rules = db.scalars(stmt).all()
    for rule in rules:
        if service_area_id and rule.service_area_id == service_area_id:
            return rule
    for rule in rules:
        if rule.service_area_id is None:
            return rule
    raise FareError("pricing_unavailable", "Pricing is not configured for this ride type.", 503)


def get_active_power_pass(db: Session, user_id: str) -> UserPowerPass | None:
    now = utcnow()
    return db.scalars(
        select(UserPowerPass)
        .where(
            UserPowerPass.user_id == user_id,
            UserPowerPass.status == "active",
            UserPowerPass.expires_at > now,
            UserPowerPass.rides_used < UserPowerPass.rides_total,
        )
        .order_by(UserPowerPass.created_at.desc())
    ).first()


def validate_coupon(
    db: Session,
    user_id: str,
    code: str,
    category: str,
    subtotal_paise: int,
    *,
    for_update: bool = False,
) -> tuple[Coupon, int]:
    stmt = select(Coupon).where(func.upper(Coupon.code) == code.upper())
    if for_update:
        stmt = stmt.with_for_update()
    coupon = db.scalar(stmt)
    now = utcnow()
    if not coupon or not coupon.is_active:
        raise FareError("coupon_invalid", "That coupon code is not valid.", 400)
    if coupon.valid_from > now or coupon.valid_until < now:
        raise FareError("coupon_expired", "That coupon has expired.", 400)
    if coupon.max_uses is not None and coupon.used_count >= coupon.max_uses:
        raise FareError("coupon_exhausted", "That coupon has reached its usage limit.", 400)
    if coupon.categories and category not in coupon.categories:
        raise FareError("coupon_category", "That coupon does not apply to this ride type.", 400)
    if subtotal_paise < coupon.min_fare_paise:
        raise FareError(
            "coupon_minimum",
            f"Add ₹{coupon.min_fare_paise / 100:.0f} more fare to use this coupon.",
            400,
        )
    used = db.scalar(
        select(func.count(CouponRedemption.id)).where(
            CouponRedemption.coupon_id == coupon.id,
            CouponRedemption.user_id == user_id,
        )
    ) or 0
    if used >= coupon.per_user_limit:
        raise FareError("coupon_used", "You have already used this coupon.", 400)
    if coupon.discount_type == "percent":
        discount = int(subtotal_paise * coupon.value / 100)
    else:
        discount = coupon.value
    if coupon.max_discount_paise:
        discount = min(discount, coupon.max_discount_paise)
    discount = min(discount, subtotal_paise)
    return coupon, discount


def compute_quote(
    db: Session,
    user: User,
    category: str,
    pickup: dict,
    drop: dict,
    coupon_code: str | None = None,
    use_power_pass: bool = True,
) -> FareQuote:
    category_row = db.scalar(
        select(ServiceCategory).where(
            ServiceCategory.code == category, ServiceCategory.is_active.is_(True)
        )
    )
    if not category_row:
        raise FareError("category_unavailable", "That ride type is unavailable.", 400)

    area = active_service_area(db, pickup["lat"], pickup["lng"])
    if not area:
        raise FareError(
            "out_of_service",
            "Pickup is outside our service area. Try a location in Bengaluru.",
            422,
        )
    if not point_in_service_area(drop["lat"], drop["lng"], area):
        raise FareError(
            "drop_out_of_service",
            "That destination is outside the current service area.",
            422,
        )

    route = route_between(pickup["lat"], pickup["lng"], drop["lat"], drop["lng"], category)
    rule = get_pricing_rule(db, category, area.id)
    mult = rule.night_multiplier
    night = _night_multiplier()
    if night > 1.0:
        mult = max(mult, night)
    km = route.distance_m / 1000
    minutes = route.duration_s / 60

    base = int(round(rule.base_fare_paise * mult))
    distance = int(round(rule.per_km_paise * km * mult))
    time_charge = int(round(rule.per_minute_paise * minutes * mult))
    subtotal = base + distance + time_charge + rule.platform_fee_paise
    lines = [
        {"label": "Base fare", "amount_paise": base},
        {"label": f"Distance · {km:.1f} km", "amount_paise": distance},
        {"label": f"Time · {minutes:.0f} min", "amount_paise": time_charge},
        {"label": "Platform fee", "amount_paise": rule.platform_fee_paise},
    ]
    if subtotal < rule.minimum_fare_paise:
        lines.append(
            {"label": "Minimum fare adjustment", "amount_paise": rule.minimum_fare_paise - subtotal}
        )
        subtotal = rule.minimum_fare_paise

    coupon = None
    coupon_discount = 0
    if coupon_code:
        coupon, coupon_discount = validate_coupon(
            db, user.id, coupon_code.strip(), category, subtotal
        )
        lines.append({"label": f"Coupon {coupon.code}", "amount_paise": -coupon_discount})

    power_pass = None
    pass_discount = 0
    if use_power_pass and not coupon:
        power_pass = get_active_power_pass(db, user.id)
        if power_pass:
            plan = db.get(PowerPassPlan, power_pass.plan_id)
            if plan:
                pass_discount = int(subtotal * plan.discount_pct / 100)
                if plan.max_discount_paise:
                    pass_discount = min(pass_discount, plan.max_discount_paise)
                pass_discount = min(pass_discount, subtotal)
                if pass_discount:
                    lines.append(
                        {
                            "label": f"Power Pass · {plan.discount_pct}%",
                            "amount_paise": -pass_discount,
                        }
                    )

    total = max(0, subtotal - coupon_discount - pass_discount)
    return FareQuote(
        category=category,
        distance_m=route.distance_m,
        duration_s=route.duration_s,
        total_paise=total,
        lines=lines,
        pricing_version=rule.version,
        coupon=coupon,
        coupon_code=coupon.code if coupon else None,
        coupon_discount_paise=coupon_discount,
        power_pass=power_pass,
        power_pass_discount_paise=pass_discount,
        service_area=area,
        route_points=route.points,
        approximate_route=route.approximate,
        route_provider=route.provider,
        surge_multiplier=mult,
        raw_subtotal_paise=subtotal,
    )


def save_estimate(
    db: Session,
    user: User,
    quote: FareQuote,
    pickup: dict,
    drop: dict,
) -> FareEstimate:
    estimate = FareEstimate(
        user_id=user.id,
        category=quote.category,
        pickup_lat=pickup["lat"],
        pickup_lng=pickup["lng"],
        drop_lat=drop["lat"],
        drop_lng=drop["lng"],
        pickup_address=pickup["address"],
        drop_address=drop["address"],
        distance_m=quote.distance_m,
        duration_s=quote.duration_s,
        total_paise=quote.total_paise,
        breakdown={"lines": quote.lines, "route_points": quote.route_points},
        pricing_version=quote.pricing_version,
        coupon_code=quote.coupon_code,
        power_pass_id=quote.power_pass.id if quote.power_pass else None,
        expires_at=utcnow() + timedelta(minutes=10),
    )
    db.add(estimate)
    db.flush()
    return estimate


def quote_token_for(estimate: FareEstimate) -> str:
    payload = {
        "sub": estimate.user_id,
        "typ": "quote",
        "est": estimate.id,
        "total": estimate.total_paise,
        "iat": int(datetime.now(timezone.utc).timestamp()),
        "exp": int((datetime.now(timezone.utc) + timedelta(minutes=10)).timestamp()),
    }
    return jwt.encode(payload, settings.secret_key, algorithm=settings.jwt_algorithm)


def read_quote_token(token: str) -> dict:
    payload = jwt.decode(
        token,
        settings.secret_key,
        algorithms=[settings.jwt_algorithm],
        options={"require": ["exp", "sub", "typ"]},
    )
    if payload.get("typ") != "quote":
        raise FareError("invalid_quote", "Invalid fare quote.", 400)
    return payload
