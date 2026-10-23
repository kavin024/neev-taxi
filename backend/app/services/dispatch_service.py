from __future__ import annotations

import logging
import math
from datetime import timedelta

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.api.deps import api_error
from app.core.config import settings
from app.core.database import utcnow
from app.core.security import (
    encrypt_trip_pin,
    generate_trip_pin,
    hash_trip_pin,
)
from app.models import (
    CaptainProfile,
    RideAssignment,
    RideRequest,
    Trip,
    User,
    Vehicle,
)
from app.services.geo import haversine_m
from app.services.realtime import add_ride_event, broadcast_ride, envelope, manager, notify_user

logger = logging.getLogger("neev.dispatch")

ACTIVE_TRIP_STATES = ("captain_arriving", "arrived", "in_progress")


def _active_trip_captain_ids(db: Session) -> set[str]:
    return set(
        db.scalars(
            select(Trip.captain_id).where(Trip.state.in_(ACTIVE_TRIP_STATES))
        ).all()
    )


def eligible_captains(
    db: Session, ride: RideRequest, *, limit: int | None = None
) -> list[tuple[CaptainProfile, int]]:
    now = utcnow()
    cutoff = now - timedelta(seconds=settings.captain_stale_location_seconds)
    busy = _active_trip_captain_ids(db)
    radius_km = settings.dispatch_radius_km
    lat_delta = radius_km / 111.0
    lng_delta = radius_km / max(0.2, 111.0 * math.cos(math.radians(ride.pickup_lat)))

    candidates = db.scalars(
        select(CaptainProfile)
        .join(User, User.id == CaptainProfile.user_id)
        .where(
            CaptainProfile.verification_status == "approved",
            CaptainProfile.is_online.is_(True),
            User.status == "active",
            CaptainProfile.last_lat.is_not(None),
            CaptainProfile.last_lng.is_not(None),
            CaptainProfile.last_location_at >= cutoff,
            CaptainProfile.last_lat.between(
                ride.pickup_lat - lat_delta, ride.pickup_lat + lat_delta
            ),
            CaptainProfile.last_lng.between(
                ride.pickup_lng - lng_delta, ride.pickup_lng + lng_delta
            ),
        )
    ).all()

    scored: list[tuple[CaptainProfile, int]] = []
    for profile in candidates:
        if profile.user_id in busy:
            continue
        vehicle = db.scalar(
            select(Vehicle).where(
                Vehicle.captain_id == profile.user_id,
                Vehicle.category == ride.category,
                Vehicle.is_active.is_(True),
            )
        )
        if not vehicle:
            continue
        distance = haversine_m(
            ride.pickup_lat, ride.pickup_lng, profile.last_lat, profile.last_lng
        )
        if distance <= radius_km * 1000:
            scored.append((profile, distance))

    scored.sort(key=lambda item: (item[1], -(item[0].rating or 0)))
    if limit:
        return scored[:limit]
    return scored


def create_offers(db: Session, ride: RideRequest) -> list[RideAssignment]:
    now = utcnow()
    eligible = eligible_captains(
        db, ride, limit=settings.max_offers_per_request
    )
    assignments: list[RideAssignment] = []
    for profile, distance in eligible:
        assignment = RideAssignment(
            ride_request_id=ride.id,
            captain_id=profile.user_id,
            distance_m=distance,
            expires_at=min(
                ride.expires_at, now + timedelta(seconds=settings.offer_timeout_seconds)
            ),
        )
        db.add(assignment)
        assignments.append(assignment)
    db.flush()
    return assignments


async def announce_offers(
    db: Session, ride: RideRequest, assignments: list[RideAssignment]
) -> None:
    from app.services.ride_service import serialize_offer

    for assignment in assignments:
        offer = serialize_offer(db, assignment, ride)
        event = envelope(
            "ride.offer",
            ride.id,
            offer,
        )
        try:
            await manager.send_to_user(assignment.captain_id, event)
        except Exception:
            logger.warning("dispatch.offer_push_failed", exc_info=True)


def accept_ride(db: Session, captain: User, ride_id: str) -> tuple[RideRequest, Trip, object | None]:
    now = utcnow()
    profile = db.get(CaptainProfile, captain.id)
    if not profile or profile.verification_status != "approved":
        raise api_error(403, "captain_not_approved", "Your captain account is not approved.")
    if not profile.is_online:
        raise api_error(403, "captain_offline", "Go online before accepting rides.")

    ride = db.get(RideRequest, ride_id)
    if not ride:
        raise api_error(404, "ride_not_found", "Ride request not found.")

    if ride.status == "assigned" and ride.assigned_captain_id == captain.id:
        trip = db.scalar(select(Trip).where(Trip.ride_request_id == ride.id))
        if trip:
            return ride, trip, None
    if ride.status != "searching":
        raise api_error(
            409,
            "ride_unavailable",
            "That ride is no longer available.",
            {"status": ride.status},
        )
    if ride.expires_at <= now:
        raise api_error(409, "ride_expired", "That request has expired.")

    assignment = db.scalar(
        select(RideAssignment).where(
            RideAssignment.ride_request_id == ride.id,
            RideAssignment.captain_id == captain.id,
        )
    )
    if not assignment or assignment.status not in {"offered"}:
        raise api_error(409, "not_offered", "This ride was not offered to you.")
    if assignment.expires_at <= now:
        assignment.status = "expired"
        db.commit()
        raise api_error(409, "offer_expired", "This offer has expired.")

    vehicle = db.scalar(
        select(Vehicle).where(
            Vehicle.captain_id == captain.id,
            Vehicle.category == ride.category,
            Vehicle.is_active.is_(True),
        )
    )
    if not vehicle:
        raise api_error(403, "vehicle_mismatch", "You have no active vehicle for this ride type.")

    active = db.scalar(
        select(Trip).where(
            Trip.captain_id == captain.id, Trip.state.in_(ACTIVE_TRIP_STATES)
        )
    )
    if active:
        raise api_error(409, "already_on_trip", "Finish your current trip before accepting another.")

    # The conditional UPDATE is the atomic arbiter: even if two captains race,
    # exactly one transaction can move the ride out of `searching`.
    result = db.execute(
        update(RideRequest)
        .where(
            RideRequest.id == ride.id,
            RideRequest.status == "searching",
            RideRequest.expires_at > now,
        )
        .values(
            status="assigned",
            assigned_captain_id=captain.id,
            assigned_at=now,
            version=RideRequest.version + 1,
        )
        .execution_options(synchronize_session=False)
    )
    if result.rowcount != 1:
        db.rollback()
        current = db.get(RideRequest, ride.id)
        if current and current.status == "assigned" and current.assigned_captain_id == captain.id:
            trip = db.scalar(select(Trip).where(Trip.ride_request_id == ride.id))
            if trip:
                return current, trip, None
        raise api_error(409, "ride_taken", "Another captain accepted this ride first.")

    trip = Trip(
        ride_request_id=ride.id,
        passenger_id=ride.passenger_id,
        captain_id=captain.id,
        vehicle_id=vehicle.id,
        state="captain_arriving",
        payment_method=ride.payment_method,
        start_pin_hash="pending",
        start_pin_enc="pending",
        pin_expires_at=now + timedelta(minutes=settings.pin_ttl_minutes),
        distance_m=ride.distance_m,
        duration_s=ride.duration_s,
    )
    db.add(trip)
    db.flush()
    pin = generate_trip_pin()
    trip.start_pin_hash = hash_trip_pin(trip.id, pin)
    trip.start_pin_enc = encrypt_trip_pin(trip.id, pin)

    assignment.status = "accepted"
    assignment.responded_at = now
    db.execute(
        update(RideAssignment)
        .where(
            RideAssignment.ride_request_id == ride.id,
            RideAssignment.captain_id != captain.id,
            RideAssignment.status == "offered",
        )
        .values(status="declined", responded_at=now)
    )

    db.refresh(ride)
    ride.status = "assigned"
    event = add_ride_event(
        db,
        ride=ride,
        event_type="ride.accepted",
        trip_id=trip.id,
        actor_user_id=captain.id,
        payload={
            "captain_id": captain.id,
            "captain_name": profile.name,
            "vehicle": vehicle.reg_number,
            "category": vehicle.category,
            "eta_to_pickup_minutes": max(1, round((assignment.distance_m or 0) / 1000 / 20 * 60)),
        },
    )
    db.commit()
    return ride, trip, event


async def after_accept(
    db: Session, ride: RideRequest, trip: Trip, event, captain: User
) -> None:
    await broadcast_ride(db, ride, event)
    await notify_user(
        db,
        user_id=ride.passenger_id,
        notification_type="ride.accepted",
        title="Captain on the way",
        body=f"{captain.captain_profile.name} accepted your ride. Your start PIN is ready.",
        data={"ride_id": ride.id, "trip_id": trip.id},
    )


def reject_offer(db: Session, captain: User, ride_id: str) -> None:
    assignment = db.scalar(
        select(RideAssignment).where(
            RideAssignment.ride_request_id == ride_id,
            RideAssignment.captain_id == captain.id,
        )
    )
    if not assignment:
        raise api_error(404, "offer_not_found", "Offer not found.")
    if assignment.status != "offered":
        raise api_error(409, "offer_responded", "You already responded to this offer.")
    assignment.status = "rejected"
    assignment.responded_at = utcnow()
    db.commit()
