from __future__ import annotations

from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import api_error
from app.core.database import utcnow
from app.core.security import decrypt_trip_pin
from app.models import (
    CouponRedemption,
    LedgerEntry,
    PaymentTransaction,
    PricingRule,
    RideAssignment,
    RideEvent,
    RideRequest,
    Trip,
    User,
    UserPowerPass,
    Vehicle,
)


def money(paise: int | None) -> str:
    if paise is None:
        return "—"
    rupees = paise / 100
    return f"₹{rupees:,.2f}" if rupees % 1 else f"₹{rupees:,.0f}"


def latest_payment(db: Session, ride_id: str) -> PaymentTransaction | None:
    return db.scalars(
        select(PaymentTransaction)
        .where(PaymentTransaction.ride_request_id == ride_id)
        .order_by(PaymentTransaction.created_at.desc())
    ).first()


def cancelled_fee(db: Session, ride: RideRequest) -> int:
    rule = db.scalars(
        select(PricingRule)
        .where(PricingRule.category == ride.category, PricingRule.is_active.is_(True))
        .order_by(PricingRule.effective_from.desc())
    ).first()
    return rule.cancellation_fee_paise if rule else 0


def serialize_ride(
    db: Session,
    ride: RideRequest,
    *,
    viewer_role: str,
    include_events: bool = False,
    since_event_id: int | None = None,
) -> dict:
    trip = ride.trip
    captain_data = None
    vehicle_data = None
    if ride.assigned_captain_id:
        captain_user = db.get(User, ride.assigned_captain_id)
        if captain_user and captain_user.captain_profile:
            c = captain_user.captain_profile
            captain_data = {
                "id": captain_user.id,
                "name": c.name,
                "phone": captain_user.phone if viewer_role == "passenger" else None,
                "rating": c.rating,
                "total_trips": c.total_trips,
                "photo_url": c.photo_url,
            }
            vehicle = db.scalars(
                select(Vehicle).where(
                    Vehicle.captain_id == captain_user.id, Vehicle.is_active.is_(True)
                )
            ).first()
            if vehicle:
                vehicle_data = {
                    "id": vehicle.id,
                    "category": vehicle.category,
                    "reg_number": vehicle.reg_number,
                    "make_model": vehicle.make_model,
                    "color": vehicle.color,
                }

    trip_data = None
    pin = None
    if trip:
        if viewer_role == "passenger" and trip.state in {"captain_arriving", "arrived"}:
            pin = decrypt_trip_pin(trip.id, trip.start_pin_enc)
        trip_data = {
            "id": trip.id,
            "state": trip.state,
            "payment_status": trip.payment_status,
            "payment_method": trip.payment_method,
            "start_pin": pin,
            "pin_expires_at": trip.pin_expires_at,
            "accepted_at": trip.accepted_at,
            "arrived_at": trip.arrived_at,
            "started_at": trip.started_at,
            "completed_at": trip.completed_at,
            "final_fare_paise": trip.final_fare_paise,
            "final_fare_display": money(trip.final_fare_paise),
            "drop_verified": trip.drop_verified,
            "distance_m": trip.distance_m,
            "duration_s": trip.duration_s,
        }

    payment = latest_payment(db, ride.id)
    payment_data = None
    if payment:
        payment_data = {
            "id": payment.id,
            "method": payment.method,
            "method_label": {
                "cash": "Cash",
                "mock_upi": "Sandbox UPI",
                "upi": "UPI",
                "card": "Card",
                "wallet": "Neev wallet",
            }.get(payment.method, payment.method),
            "provider": payment.provider,
            "status": payment.status,
            "amount_paise": payment.amount_paise,
            "amount_display": money(payment.amount_paise),
            "is_sandbox": payment.provider == "sandbox",
            "signature_verified": payment.signature_verified,
            "created_at": payment.created_at,
        }

    events = []
    if include_events:
        stmt = select(RideEvent).where(RideEvent.ride_request_id == ride.id)
        if since_event_id:
            stmt = stmt.where(RideEvent.id > since_event_id)
        for event in db.scalars(stmt.order_by(RideEvent.id.asc()).limit(200)).all():
            events.append(
                {
                    "event_id": event.id,
                    "type": event.event_type,
                    "payload": event.payload,
                    "created_at": event.created_at,
                }
            )

    data = {
        "id": ride.id,
        "category": ride.category,
        "status": ride.status,
        "payment_method": ride.payment_method,
        "pickup": {
            "lat": ride.pickup_lat,
            "lng": ride.pickup_lng,
            "address": ride.pickup_address,
        },
        "drop": {
            "lat": ride.drop_lat,
            "lng": ride.drop_lng,
            "address": ride.drop_address,
        },
        "distance_m": ride.distance_m,
        "duration_s": ride.duration_s,
        "quoted_fare_paise": ride.quoted_fare_paise,
        "quoted_fare_display": money(ride.quoted_fare_paise),
        "fare_breakdown": ride.fare_breakdown,
        "discount_paise": ride.discount_paise,
        "route_points": ride.route_points or [],
        "captain": captain_data,
        "vehicle": vehicle_data,
        "trip": trip_data,
        "payment": payment_data,
        "expires_at": ride.expires_at,
        "assigned_at": ride.assigned_at,
        "cancelled_at": ride.cancelled_at,
        "cancelled_by": ride.cancelled_by,
        "cancellation_reason": ride.cancellation_reason,
        "cancellation_fee_paise": ride.cancellation_fee_paise,
        "cancellation_fee_display": money(ride.cancellation_fee_paise),
        "possible_cancellation_fee_paise": (
            cancelled_fee(db, ride)
            if ride.status == "assigned"
            and trip
            and trip.state in {"captain_arriving", "arrived"}
            else 0
        ),
        "created_at": ride.created_at,
        "version": ride.version,
    }
    if viewer_role == "admin":
        # Operators need to navigate from a ride to the passenger record.
        # Captains and passengers never receive another account's identifier here.
        data["passenger_id"] = ride.passenger_id
    if events:
        data["events"] = events
    return data


def serialize_offer(db: Session, assignment: RideAssignment, ride: RideRequest) -> dict:
    captain = db.get(User, assignment.captain_id)
    profile = captain.captain_profile if captain else None
    return {
        "ride_id": ride.id,
        "category": ride.category,
        "pickup": {
            "lat": ride.pickup_lat,
            "lng": ride.pickup_lng,
            "address": ride.pickup_address,
        },
        "drop": {
            "lat": ride.drop_lat,
            "lng": ride.drop_lng,
            "address": ride.drop_address,
        },
        "distance_m": ride.distance_m,
        "duration_s": ride.duration_s,
        "fare_paise": ride.quoted_fare_paise,
        "fare_display": money(ride.quoted_fare_paise),
        "distance_to_pickup_m": assignment.distance_m,
        "expires_at": assignment.expires_at,
        "passenger_name": "Neev rider",
        "captain_rating": profile.rating if profile else None,
    }


def restore_discount_reservations(db: Session, ride: RideRequest) -> None:
    """Return coupon and Power Pass usage when a trip never starts."""
    if ride.power_pass_id:
        power_pass = db.get(UserPowerPass, ride.power_pass_id)
        if power_pass and power_pass.rides_used > 0:
            power_pass.rides_used -= 1
    if ride.coupon_id:
        redemption = db.scalar(
            select(CouponRedemption).where(
                CouponRedemption.coupon_id == ride.coupon_id,
                CouponRedemption.ride_request_id == ride.id,
            )
        )
        if redemption:
            from app.models import Coupon

            coupon = db.get(Coupon, ride.coupon_id)
            if coupon and coupon.used_count > 0:
                coupon.used_count -= 1
            db.delete(redemption)


def advance_trip(
    db: Session,
    trip: Trip,
    new_state: str,
    *,
    actor_id: str,
    allowed_from: set[str],
) -> None:
    if trip.state not in allowed_from:
        raise api_error(
            409,
            "invalid_state",
            f"Trip is {trip.state.replace('_', ' ')} and cannot move to {new_state.replace('_', ' ')}.",
            {"current_state": trip.state},
        )
    trip.state = new_state
    trip.version += 1
    db.add(trip)


def record_cancellation_fee(
    db: Session, ride: RideRequest, fee_paise: int, *, cancelled_by: str
) -> None:
    if fee_paise <= 0:
        return
    db.add(
        LedgerEntry(
            account_type="platform_receivable",
            user_id=ride.passenger_id,
            ride_request_id=ride.id,
            entry_type="cancellation_fee_due",
            amount_paise=fee_paise,
            description=f"Cancellation fee recorded after {cancelled_by} cancellation (not auto-charged)",
            metadata_json={"collected": False},
        )
    )
