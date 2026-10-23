from __future__ import annotations

import logging
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import api_error, get_approved_captain, get_captain, get_current_user, get_passenger
from app.core.config import settings
from app.core.database import get_db, utcnow
from app.core.security import verify_trip_pin
from app.models import (
    CaptainProfile,
    Coupon,
    CouponRedemption,
    LedgerEntry,
    LocationUpdate,
    PaymentTransaction,
    PayoutRequest,
    Rating,
    RideAssignment,
    RideEvent,
    RideRequest,
    SupportTicket,
    Trip,
    TripShare,
    User,
    UserPowerPass,
    Vehicle,
)
from app.schemas.common import Message
from app.schemas.rides import (
    LocationUpdateBody,
    PayoutRequestBody,
    RatingBody,
    RideCancelBody,
    RideRequestBody,
    ShareTripBody,
    TripCompleteBody,
    TripStartBody,
)
from app.services.dispatch_service import (
    accept_ride,
    after_accept,
    announce_offers,
    create_offers,
    eligible_captains,
    reject_offer,
)
from app.services.fare_service import (
    FareError,
    compute_quote,
    get_pricing_rule,
    save_estimate,
)
from app.services.geo import haversine_m
from app.services.ledger_service import balance_paise, request_payout
from app.services.realtime import (
    add_ride_event,
    broadcast_ride,
    envelope,
    manager,
    notify_user,
)
from app.services.ride_service import (
    cancelled_fee,
    money,
    record_cancellation_fee,
    restore_discount_reservations,
    serialize_offer,
    serialize_ride,
)
from app.services.security_utils import hash_share_token

logger = logging.getLogger("neev.rides")
router = APIRouter(tags=["rides and trips"])

PARTICIPANT_TRIP_STATES = {"captain_arriving", "arrived", "in_progress", "completed"}


def _ride_for_participant(db: Session, ride_id: str, user: User) -> RideRequest:
    ride = db.get(RideRequest, ride_id)
    if not ride:
        raise api_error(404, "ride_not_found", "Ride not found.")
    if user.id not in {ride.passenger_id, ride.assigned_captain_id} and user.role != "admin":
        raise api_error(403, "forbidden", "You do not have access to this ride.")
    return ride


@router.post("/rides/request", status_code=201)
async def request_ride(
    body: RideRequestBody,
    request: Request,
    db: Session = Depends(get_db),
    user: User = Depends(get_passenger),
):
    existing = db.scalar(
        select(RideRequest).where(
            RideRequest.passenger_id == user.id,
            RideRequest.idempotency_key == body.idempotency_key,
        )
    )
    if existing:
        if (
            existing.category != body.category
            or abs(existing.pickup_lat - body.pickup.lat) > 1e-6
            or abs(existing.drop_lat - body.drop.lat) > 1e-6
        ):
            raise api_error(409, "idempotency_conflict", "This idempotency key was used for a different ride.")
        return serialize_ride(db, existing, viewer_role="passenger", include_events=True)

    active = db.scalar(
        select(RideRequest).where(
            RideRequest.passenger_id == user.id,
            RideRequest.status.in_(["searching", "assigned"]),
        )
    )
    if active:
        raise api_error(
            409,
            "active_ride",
            "You already have a ride in progress.",
            {"ride_id": active.id},
        )

    recent_duplicate = db.scalar(
        select(RideRequest).where(
            RideRequest.passenger_id == user.id,
            RideRequest.created_at > utcnow() - timedelta(minutes=2),
            RideRequest.status.in_(["searching", "assigned"]),
        )
    )
    if recent_duplicate:
        raise api_error(409, "duplicate_request", "A similar request was just created.")

    try:
        quote = compute_quote(
            db,
            user,
            body.category,
            body.pickup.model_dump(),
            body.drop.model_dump(),
            body.coupon_code,
            body.use_power_pass,
        )
    except FareError as exc:
        raise api_error(exc.status_code, exc.code, exc.message, exc.details)

    # Reserve coupon atomically.
    coupon = None
    coupon_discount = quote.coupon_discount_paise
    if quote.coupon:
        coupon = db.scalar(
            select(Coupon).where(Coupon.id == quote.coupon.id).with_for_update()
        )
        if (
            not coupon
            or not coupon.is_active
            or (coupon.max_uses is not None and coupon.used_count >= coupon.max_uses)
        ):
            raise api_error(409, "coupon_unavailable", "That coupon is no longer available.")
        used = db.scalar(
            select(func.count(CouponRedemption.id)).where(
                CouponRedemption.coupon_id == coupon.id,
                CouponRedemption.user_id == user.id,
            )
        ) or 0
        if used >= coupon.per_user_limit:
            raise api_error(400, "coupon_used", "You have already used this coupon.")
        coupon.used_count += 1

    # Reserve Power Pass ride atomically.
    power_pass = None
    pass_discount = quote.power_pass_discount_paise
    if quote.power_pass:
        power_pass = db.scalar(
            select(UserPowerPass)
            .where(UserPowerPass.id == quote.power_pass.id)
            .with_for_update()
        )
        now = utcnow()
        if (
            not power_pass
            or power_pass.status != "active"
            or power_pass.expires_at <= now
            or power_pass.rides_used >= power_pass.rides_total
        ):
            quote = compute_quote(
                db,
                user,
                body.category,
                body.pickup.model_dump(),
                body.drop.model_dump(),
                body.coupon_code,
                use_power_pass=False,
            )
            power_pass = None
            pass_discount = 0
            coupon_discount = 0
        else:
            power_pass.rides_used += 1

    rule = get_pricing_rule(db, body.category, quote.service_area.id if quote.service_area else None)
    expires_at = utcnow() + timedelta(seconds=settings.search_timeout_seconds)
    ride = RideRequest(
        passenger_id=user.id,
        category=body.category,
        pickup_lat=body.pickup.lat,
        pickup_lng=body.pickup.lng,
        pickup_address=body.pickup.address,
        drop_lat=body.drop.lat,
        drop_lng=body.drop.lng,
        drop_address=body.drop.address,
        distance_m=quote.distance_m,
        duration_s=quote.duration_s,
        quoted_fare_paise=quote.total_paise,
        fare_breakdown={
            "lines": quote.lines,
            "commission_pct": rule.commission_pct,
            "platform_fee_paise": rule.platform_fee_paise,
            "pricing_version": quote.pricing_version,
            "coupon_code": quote.coupon_code,
            "power_pass_id": power_pass.id if power_pass else None,
            "route_provider": quote.route_provider,
            "approximate_route": quote.approximate_route,
            "currency": "INR",
        },
        route_points=[[p[0], p[1]] for p in quote.route_points],
        pricing_version=quote.pricing_version,
        coupon_id=coupon.id if coupon else None,
        discount_paise=coupon_discount + pass_discount,
        power_pass_id=power_pass.id if power_pass else None,
        payment_method=body.payment_method,
        status="searching",
        idempotency_key=body.idempotency_key,
        request_ip=request.client.host if request.client else None,
        expires_at=expires_at,
    )
    db.add(ride)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        existing = db.scalar(
            select(RideRequest).where(
                RideRequest.passenger_id == user.id,
                RideRequest.idempotency_key == body.idempotency_key,
            )
        )
        if existing:
            return serialize_ride(db, existing, viewer_role="passenger", include_events=True)
        raise

    if coupon:
        db.add(
            CouponRedemption(
                coupon_id=coupon.id,
                user_id=user.id,
                ride_request_id=ride.id,
                discount_paise=coupon_discount,
            )
        )
    events = []
    event = add_ride_event(
        db,
        ride=ride,
        event_type="ride.requested",
        actor_user_id=user.id,
        payload={
            "category": body.category,
            "quoted_fare_paise": ride.quoted_fare_paise,
            "pickup": body.pickup.model_dump(),
            "drop": body.drop.model_dump(),
            "search_expires_at": expires_at.isoformat(),
        },
    )
    assignments = create_offers(db, ride)
    db.commit()
    db.refresh(ride)
    await announce_offers(db, ride, assignments)
    payload = serialize_ride(db, ride, viewer_role="passenger", include_events=True)
    payload["offers_sent"] = len(assignments)
    payload["captains_available"] = len(eligible_captains(db, ride))
    if not assignments:
        payload["message"] = (
            "No captain is online nearby yet. We will keep searching until the request expires."
        )
    return payload


@router.get("/rides")
def list_rides(
    status: str | None = None,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    stmt = select(RideRequest)
    if user.role == "passenger":
        stmt = stmt.where(RideRequest.passenger_id == user.id)
    elif user.role == "captain":
        stmt = stmt.where(RideRequest.assigned_captain_id == user.id)
    else:
        raise api_error(403, "forbidden", "Use the admin API.")
    if status:
        stmt = stmt.where(RideRequest.status == status)
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(
        stmt.order_by(RideRequest.created_at.desc()).offset(offset).limit(limit)
    ).all()
    return {
        "items": [serialize_ride(db, r, viewer_role=user.role) for r in rows],
        "total": total,
        "limit": limit,
        "offset": offset,
    }


@router.get("/rides/{ride_id}")
def get_ride(
    ride_id: str,
    since_event_id: int | None = Query(default=None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ride = _ride_for_participant(db, ride_id, user)
    data = serialize_ride(
        db, ride, viewer_role=user.role, include_events=True, since_event_id=since_event_id
    )
    data["server_time"] = utcnow()
    return data


@router.get("/rides/{ride_id}/locations")
def get_locations(
    ride_id: str,
    limit: int = Query(200, ge=1, le=1000),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ride = _ride_for_participant(db, ride_id, user)
    if not ride.trip:
        return {"items": [], "simulated": False}
    rows = db.scalars(
        select(LocationUpdate)
        .where(LocationUpdate.trip_id == ride.trip.id)
        .order_by(LocationUpdate.recorded_at.desc())
        .limit(limit)
    ).all()
    rows = list(reversed(rows))
    return {
        "items": [
            {
                "lat": r.lat,
                "lng": r.lng,
                "accuracy_m": r.accuracy_m,
                "speed_mps": r.speed_mps,
                "heading": r.heading,
                "source": r.source,
                "recorded_at": r.recorded_at,
                "received_at": r.received_at,
            }
            for r in rows
        ],
        "simulated": any(r.source == "simulated" for r in rows),
    }


@router.post("/rides/{ride_id}/cancel")
async def cancel_ride(
    ride_id: str,
    body: RideCancelBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ride = db.scalar(select(RideRequest).where(RideRequest.id == ride_id).with_for_update())
    if not ride:
        raise api_error(404, "ride_not_found", "Ride not found.")
    if user.id not in {ride.passenger_id, ride.assigned_captain_id}:
        raise api_error(403, "forbidden", "You cannot cancel this ride.")
    if ride.status not in {"searching", "assigned"}:
        raise api_error(409, "not_cancellable", f"This ride is already {ride.status}.")
    trip = ride.trip
    if trip and trip.state == "in_progress":
        raise api_error(
            409,
            "trip_in_progress",
            "A trip in progress cannot be cancelled in the app. Use SOS if you are unsafe or contact support.",
        )
    fee = 0
    if ride.status == "assigned" and trip and trip.state in {"captain_arriving", "arrived"}:
        fee = cancelled_fee(db, ride)
    actor = "passenger" if user.id == ride.passenger_id else "captain"
    if actor == "passenger" and fee > 0 and not body.accept_cancellation_fee:
        raise api_error(
            409,
            "cancellation_fee_required",
            f"A {money(fee)} cancellation fee applies because a captain is already on the way.",
            {"fee_paise": fee, "fee_display": money(fee), "requires_confirmation": True},
        )

    now = utcnow()
    ride.status = "cancelled"
    ride.cancelled_at = now
    ride.cancelled_by = actor
    ride.cancellation_reason = body.reason
    ride.cancellation_fee_paise = fee
    ride.version += 1
    if trip:
        trip.state = "cancelled"
        trip.cancelled_at = now
        trip.cancelled_by = actor
        trip.cancel_reason = body.reason
        trip.version += 1
    db.execute(
        RideAssignment.__table__.update()
        .where(RideAssignment.ride_request_id == ride.id, RideAssignment.status == "offered")
        .values(status="expired", responded_at=now)
    )
    restore_discount_reservations(db, ride)
    record_cancellation_fee(db, ride, fee, cancelled_by=actor)
    event = add_ride_event(
        db,
        ride=ride,
        event_type="ride.cancelled",
        actor_user_id=user.id,
        payload={
            "cancelled_by": actor,
            "reason": body.reason,
            "cancellation_fee_paise": fee,
        },
    )
    db.commit()
    db.refresh(ride)
    await broadcast_ride(db, ride, event)
    other = ride.assigned_captain_id if actor == "passenger" else ride.passenger_id
    if other:
        await notify_user(
            db,
            user_id=other,
            notification_type="ride.cancelled",
            title="Ride cancelled",
            body=f"The {actor} cancelled this ride. {body.reason}",
            data={"ride_id": ride.id},
        )
    return serialize_ride(db, ride, viewer_role=user.role, include_events=True)


@router.post("/rides/{ride_id}/rate")
async def rate_ride(
    ride_id: str,
    body: RatingBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ride = _ride_for_participant(db, ride_id, user)
    trip = ride.trip
    if not trip or trip.state != "completed":
        raise api_error(409, "not_completed", "You can rate after the trip is completed.")
    ratee_id = ride.assigned_captain_id if user.id == ride.passenger_id else ride.passenger_id
    if not ratee_id:
        raise api_error(409, "rating_unavailable", "There is no one to rate for this ride.")
    existing = db.scalar(
        select(Rating).where(Rating.trip_id == trip.id, Rating.rater_id == user.id)
    )
    if existing:
        raise api_error(409, "already_rated", "You already rated this trip.")
    rating = Rating(
        trip_id=trip.id,
        rater_id=user.id,
        ratee_id=ratee_id,
        rater_role=user.role,
        stars=body.stars,
        comment=body.comment,
        tags=body.tags,
    )
    db.add(rating)
    ratee = db.get(User, ratee_id)
    if ratee and ratee.role == "captain" and ratee.captain_profile:
        ratee.captain_profile.rating_sum += body.stars
        ratee.captain_profile.rating_count += 1
    elif ratee and ratee.passenger_profile:
        ratee.passenger_profile.rating_sum += body.stars
        ratee.passenger_profile.rating_count += 1
    db.commit()
    return {
        "id": rating.id,
        "stars": rating.stars,
        "comment": rating.comment,
        "message": "Thanks for your feedback.",
    }


# ----------------------------- Captain endpoints -----------------------------


@router.get("/captain/offers")
def captain_offers(
    db: Session = Depends(get_db), captain: User = Depends(get_approved_captain)
):
    now = utcnow()
    rows = db.execute(
        select(RideAssignment, RideRequest)
        .join(RideRequest, RideRequest.id == RideAssignment.ride_request_id)
        .where(
            RideAssignment.captain_id == captain.id,
            RideAssignment.status == "offered",
            RideAssignment.expires_at > now,
            RideRequest.status == "searching",
        )
        .order_by(RideAssignment.offered_at.desc())
    ).all()
    profile = db.get(CaptainProfile, captain.id)
    return {
        "items": [serialize_offer(db, a, r) for a, r in rows],
        "is_online": profile.is_online if profile else False,
        "server_time": now,
    }


@router.post("/captain/offers/{ride_id}/accept")
async def captain_accept(
    ride_id: str,
    db: Session = Depends(get_db),
    captain: User = Depends(get_approved_captain),
):
    ride, trip, event = accept_ride(db, captain, ride_id)
    if event:
        await after_accept(db, ride, trip, event, captain)
    data = serialize_ride(db, ride, viewer_role="captain", include_events=True)
    return data


@router.post("/captain/offers/{ride_id}/reject", response_model=Message)
def captain_reject(
    ride_id: str,
    db: Session = Depends(get_db),
    captain: User = Depends(get_approved_captain),
):
    reject_offer(db, captain, ride_id)
    return Message(message="Offer declined.")


@router.post("/captain/trips/{trip_id}/arrived")
async def captain_arrived(
    trip_id: str,
    db: Session = Depends(get_db),
    captain: User = Depends(get_approved_captain),
):
    trip = db.scalar(select(Trip).where(Trip.id == trip_id).with_for_update())
    if not trip or trip.captain_id != captain.id:
        raise api_error(404, "trip_not_found", "Trip not found.")
    if trip.state != "captain_arriving":
        raise api_error(409, "invalid_state", "Trip is not in the arriving state.")
    trip.state = "arrived"
    trip.arrived_at = utcnow()
    trip.version += 1
    ride = db.get(RideRequest, trip.ride_request_id)
    event = add_ride_event(
        db, ride=ride, event_type="captain.arrived", trip_id=trip.id, actor_user_id=captain.id, payload={}
    )
    db.commit()
    await broadcast_ride(db, ride, event)
    await notify_user(
        db,
        user_id=trip.passenger_id,
        notification_type="captain.arrived",
        title="Your captain has arrived",
        body="Share your 4-digit start PIN with the captain to begin the trip.",
        data={"ride_id": ride.id},
    )
    return serialize_ride(db, ride, viewer_role="captain", include_events=True)


@router.post("/captain/trips/{trip_id}/start")
async def captain_start(
    trip_id: str,
    body: TripStartBody,
    db: Session = Depends(get_db),
    captain: User = Depends(get_approved_captain),
):
    trip = db.scalar(select(Trip).where(Trip.id == trip_id).with_for_update())
    if not trip or trip.captain_id != captain.id:
        raise api_error(404, "trip_not_found", "Trip not found.")
    if trip.state not in {"captain_arriving", "arrived"}:
        raise api_error(409, "invalid_state", "This trip cannot be started from its current state.")
    now = utcnow()
    if trip.pin_locked_until and trip.pin_locked_until > now:
        raise api_error(429, "pin_locked", "Too many incorrect PIN attempts. Try again later.")
    if trip.pin_expires_at < now:
        raise api_error(410, "pin_expired", "The start PIN has expired. Contact support to resume this trip.")
    if not verify_trip_pin(trip.id, body.pin, trip.start_pin_hash):
        trip.pin_attempts += 1
        if trip.pin_attempts >= settings.pin_max_attempts:
            trip.pin_locked_until = now + timedelta(minutes=15)
        db.commit()
        remaining = max(0, settings.pin_max_attempts - trip.pin_attempts)
        raise api_error(
            401,
            "pin_invalid",
            "That start PIN is incorrect.",
            {"attempts_remaining": remaining},
        )
    trip.state = "in_progress"
    trip.started_at = now
    trip.version += 1
    ride = db.get(RideRequest, trip.ride_request_id)
    event = add_ride_event(
        db,
        ride=ride,
        event_type="trip.started",
        trip_id=trip.id,
        actor_user_id=captain.id,
        payload={"started_at": now.isoformat()},
    )
    db.commit()
    await broadcast_ride(db, ride, event)
    await notify_user(
        db,
        user_id=trip.passenger_id,
        notification_type="trip.started",
        title="Trip started",
        body="Your trip is now in progress. Live location sharing is available.",
        data={"ride_id": ride.id},
    )
    return serialize_ride(db, ride, viewer_role="captain", include_events=True)


@router.post("/captain/trips/{trip_id}/location")
async def captain_location(
    trip_id: str,
    body: LocationUpdateBody,
    db: Session = Depends(get_db),
    captain: User = Depends(get_approved_captain),
):
    trip = db.get(Trip, trip_id)
    if not trip or trip.captain_id != captain.id:
        raise api_error(404, "trip_not_found", "Trip not found.")
    if trip.state not in {"captain_arriving", "arrived", "in_progress"}:
        raise api_error(409, "invalid_state", "Location updates are closed for this trip.")
    if body.source == "simulated" and not settings.dev_allow_gps_simulation:
        raise api_error(403, "simulation_disabled", "GPS simulation is disabled in this environment.")
    recorded = body.recorded_at
    if recorded.tzinfo is None:
        recorded = recorded.replace(tzinfo=timezone.utc)
    now = utcnow()
    age = (now - recorded).total_seconds()
    if age > settings.location_max_age_seconds:
        raise api_error(422, "stale_location", "Location fix is too old. Send a fresh reading.", {"age_seconds": int(age)})
    if age < -60:
        raise api_error(422, "future_timestamp", "Location timestamp is in the future.")
    last = db.scalars(
        select(LocationUpdate)
        .where(LocationUpdate.trip_id == trip.id)
        .order_by(LocationUpdate.recorded_at.desc())
        .limit(1)
    ).first()
    if last and recorded <= last.recorded_at:
        raise api_error(409, "stale_update", "Location update is older than the last accepted reading.")
    update = LocationUpdate(
        trip_id=trip.id,
        captain_id=captain.id,
        lat=body.lat,
        lng=body.lng,
        accuracy_m=body.accuracy_m,
        speed_mps=body.speed_mps,
        heading=body.heading,
        source=body.source,
        recorded_at=recorded,
    )
    db.add(update)
    profile = db.get(CaptainProfile, captain.id)
    if profile:
        profile.last_lat = body.lat
        profile.last_lng = body.lng
        profile.last_location_at = now
        profile.last_location_source = body.source
    ride = db.get(RideRequest, trip.ride_request_id)
    event = add_ride_event(
        db,
        ride=ride,
        event_type="captain.location_updated",
        trip_id=trip.id,
        actor_user_id=captain.id,
        payload={
            "lat": body.lat,
            "lng": body.lng,
            "accuracy_m": body.accuracy_m,
            "speed_mps": body.speed_mps,
            "heading": body.heading,
            "source": body.source,
            "recorded_at": recorded.isoformat(),
        },
    )
    db.commit()
    await broadcast_ride(db, ride, event)
    return {
        "accepted": True,
        "recorded_at": recorded,
        "source": body.source,
        "event_id": event.id,
    }


@router.post("/captain/trips/{trip_id}/complete")
async def captain_complete(
    trip_id: str,
    body: TripCompleteBody,
    db: Session = Depends(get_db),
    captain: User = Depends(get_approved_captain),
):
    trip = db.scalar(select(Trip).where(Trip.id == trip_id).with_for_update())
    if not trip or trip.captain_id != captain.id:
        raise api_error(404, "trip_not_found", "Trip not found.")
    if trip.state != "in_progress":
        raise api_error(409, "invalid_state", "Only a trip in progress can be completed.")
    ride = db.get(RideRequest, trip.ride_request_id)
    now = utcnow()
    drop_verified = None
    if body.lat is not None and body.lng is not None:
        distance = haversine_m(body.lat, body.lng, ride.drop_lat, ride.drop_lng)
        drop_verified = distance <= 200
        if not drop_verified:
            db.add(
                SupportTicket(
                    user_id=trip.passenger_id,
                    ride_request_id=ride.id,
                    category="driver",
                    subject="Drop location outside 200 m tolerance",
                    description=(
                        "The trip was completed away from the booked destination. "
                        f"Completion point was {distance} m from the drop-off. Please review."
                    ),
                    status="open",
                    priority="normal",
                )
            )
    trip.state = "completed"
    trip.completed_at = now
    trip.final_fare_paise = ride.quoted_fare_paise
    trip.fare_breakdown = ride.fare_breakdown
    trip.completed_lat = body.lat
    trip.completed_lng = body.lng
    trip.drop_verified = drop_verified
    trip.duration_s = int((now - trip.started_at).total_seconds()) if trip.started_at else ride.duration_s
    trip.version += 1
    ride.status = "completed"
    ride.version += 1

    # Cash is collected in person, so open a pending cash payment the passenger
    # explicitly confirms. Online/sandbox payments stay passenger-initiated.
    if (trip.payment_method or "cash") == "cash":
        existing_payment = db.scalar(
            select(PaymentTransaction).where(
                PaymentTransaction.ride_request_id == ride.id,
                PaymentTransaction.purpose == "ride",
                PaymentTransaction.status.in_(["created", "pending", "captured"]),
            )
        )
        if not existing_payment:
            db.add(
                PaymentTransaction(
                    ride_request_id=ride.id,
                    trip_id=trip.id,
                    user_id=trip.passenger_id,
                    purpose="ride",
                    amount_paise=trip.final_fare_paise,
                    method="cash",
                    provider="cash",
                    status="pending",
                    metadata_json={
                        "note": "Cash is collected by the captain; the passenger confirms handover."
                    },
                )
            )
    passenger_profile = ride.passenger_id and db.get(User, ride.passenger_id)
    if passenger_profile and passenger_profile.passenger_profile:
        passenger_profile.passenger_profile.total_rides += 1
    profile = db.get(CaptainProfile, captain.id)
    if profile:
        profile.total_trips += 1
    event = add_ride_event(
        db,
        ride=ride,
        event_type="trip.completed",
        trip_id=trip.id,
        actor_user_id=captain.id,
        payload={
            "final_fare_paise": trip.final_fare_paise,
            "payment_status": trip.payment_status,
            "drop_verified": drop_verified,
            "duration_s": trip.duration_s,
        },
    )
    db.commit()
    await broadcast_ride(db, ride, event)
    await notify_user(
        db,
        user_id=trip.passenger_id,
        notification_type="trip.completed",
        title="Trip completed",
        body=f"Your fare is {money(trip.final_fare_paise)}. Choose a payment method to finish up.",
        data={"ride_id": ride.id, "payment_methods": True},
    )
    return serialize_ride(db, ride, viewer_role="captain", include_events=True)


@router.get("/captain/trips")
def captain_trips(
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    captain: User = Depends(get_approved_captain),
):
    rows = db.scalars(
        select(RideRequest)
        .where(RideRequest.assigned_captain_id == captain.id)
        .order_by(RideRequest.created_at.desc())
        .offset(offset)
        .limit(limit)
    ).all()
    return {"items": [serialize_ride(db, r, viewer_role="captain") for r in rows]}


@router.get("/captain/earnings")
def captain_earnings(
    db: Session = Depends(get_db), captain: User = Depends(get_approved_captain)
):
    now = utcnow()
    start_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_start = start_today - timedelta(days=start_today.weekday())
    entries = db.scalars(
        select(LedgerEntry)
        .where(
            LedgerEntry.user_id == captain.id,
            LedgerEntry.account_type == "captain_earnings",
        )
        .order_by(LedgerEntry.created_at.desc())
    ).all()
    earnings = [e for e in entries if e.entry_type == "trip_earning"]

    def total_since(dt):
        return sum(e.amount_paise for e in earnings if e.created_at >= dt)

    payouts = db.scalars(
        select(PayoutRequest)
        .where(PayoutRequest.captain_id == captain.id)
        .order_by(PayoutRequest.requested_at.desc())
    ).all()
    available = balance_paise(db, "captain_earnings", captain.id)
    trip_rows = db.execute(
        select(RideRequest, Trip)
        .join(Trip, Trip.ride_request_id == RideRequest.id)
        .where(Trip.captain_id == captain.id, Trip.state == "completed")
        .order_by(Trip.completed_at.desc())
        .limit(30)
    ).all()
    return {
        "today_paise": total_since(start_today),
        "today_display": money(total_since(start_today)),
        "week_paise": total_since(week_start),
        "week_display": money(total_since(week_start)),
        "lifetime_paise": sum(e.amount_paise for e in earnings),
        "lifetime_display": money(sum(e.amount_paise for e in earnings)),
        "available_paise": available,
        "available_display": money(available),
        "currency": "INR",
        "platform_commission_note": "Earnings shown are net of platform commission recorded per trip.",
        "trips": [
            {
                "ride_id": ride.id,
                "trip_id": trip.id,
                "fare_paise": trip.final_fare_paise,
                "fare_display": money(trip.final_fare_paise),
                "completed_at": trip.completed_at,
                "payment_status": trip.payment_status,
            }
            for ride, trip in trip_rows
        ],
        "payouts": [
            {
                "id": p.id,
                "amount_paise": p.amount_paise,
                "amount_display": money(p.amount_paise),
                "status": p.status,
                "method": p.method,
                "destination_masked": p.destination_masked,
                "requested_at": p.requested_at,
                "processed_at": p.processed_at,
            }
            for p in payouts
        ],
    }


@router.post("/captain/payouts", status_code=201)
def create_payout(
    body: PayoutRequestBody,
    db: Session = Depends(get_db),
    captain: User = Depends(get_approved_captain),
):
    payout = request_payout(
        db, captain.id, body.amount_paise, body.method, body.destination
    )
    return {
        "id": payout.id,
        "amount_paise": payout.amount_paise,
        "amount_display": money(payout.amount_paise),
        "status": payout.status,
        "destination_masked": payout.destination_masked,
        "note": "Payouts require manual admin review in this build. Completion is recorded only after an admin confirms settlement.",
    }


@router.post("/rides/{ride_id}/share", status_code=201)
def create_share_link(
    ride_id: str,
    body: ShareTripBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_passenger),
):
    ride = _ride_for_participant(db, ride_id, user)
    if not ride.trip:
        raise api_error(409, "no_active_trip", "A captain must accept before sharing a live trip.")
    if ride.trip.state in {"cancelled", "completed"}:
        raise api_error(409, "trip_closed", "This trip is no longer live.")
    raw = secrets.token_urlsafe(32)
    share = TripShare(
        trip_id=ride.trip.id,
        created_by=user.id,
        token_hash=hash_share_token(raw),
        expires_at=utcnow() + timedelta(minutes=min(body.duration_minutes, settings.share_link_ttl_minutes)),
    )
    db.add(share)
    db.commit()
    return {
        "share_id": share.id,
        "url": f"{settings.public_base_url}/share/{raw}",
        "expires_at": share.expires_at,
        "note": "Anyone with this unlisted link can view limited live trip details until it expires.",
    }


@router.get("/passenger/ride-events")
def recent_events(
    db: Session = Depends(get_db), user: User = Depends(get_passenger)
):
    rows = db.scalars(
        select(RideEvent)
        .join(RideRequest, RideRequest.id == RideEvent.ride_request_id)
        .where(RideRequest.passenger_id == user.id)
        .order_by(RideEvent.id.desc())
        .limit(50)
    ).all()
    return [
        {"event_id": e.id, "ride_id": e.ride_request_id, "type": e.event_type, "payload": e.payload, "created_at": e.created_at}
        for e in rows
    ]
