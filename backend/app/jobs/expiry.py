from __future__ import annotations

import asyncio
import logging
from datetime import timedelta

from sqlalchemy import select, update

from app.core.config import settings
from app.core.database import SessionLocal, utcnow
from app.models import RideAssignment, RideRequest, UserPowerPass
from app.services.realtime import add_ride_event, broadcast_ride, notify_user

logger = logging.getLogger("neev.jobs")


async def expire_once() -> int:
    now = utcnow()
    expired = 0
    with SessionLocal() as db:
        rides = db.scalars(
            select(RideRequest).where(
                RideRequest.status == "searching", RideRequest.expires_at <= now
            )
        ).all()
        for ride in rides:
            # Conditional update avoids racing a captain acceptance.
            result = db.execute(
                update(RideRequest)
                .where(
                    RideRequest.id == ride.id,
                    RideRequest.status == "searching",
                )
                .values(status="expired", version=RideRequest.version + 1)
                .execution_options(synchronize_session=False)
            )
            if result.rowcount != 1:
                db.rollback()
                continue
            db.refresh(ride)
            db.execute(
                update(RideAssignment)
                .where(
                    RideAssignment.ride_request_id == ride.id,
                    RideAssignment.status == "offered",
                )
                .values(status="expired", responded_at=now)
            )
            event = add_ride_event(
                db,
                ride=ride,
                event_type="ride.expired",
                payload={"reason": "no_captain_available"},
            )
            db.commit()
            expired += 1
            await broadcast_ride(db, ride, event)
            await notify_user(
                db,
                user_id=ride.passenger_id,
                notification_type="ride.expired",
                title="No captain available",
                body="We could not find a captain nearby. You can try again or choose another ride type.",
                data={"ride_id": ride.id},
            )

        db.execute(
            update(RideAssignment)
            .where(
                RideAssignment.status == "offered",
                RideAssignment.expires_at <= now,
            )
            .values(status="expired", responded_at=now)
        )
        db.execute(
            update(UserPowerPass)
            .where(
                UserPowerPass.status == "active", UserPowerPass.expires_at <= now
            )
            .values(status="expired")
        )
        db.commit()
    return expired


async def expiry_loop() -> None:
    while True:
        try:
            count = await expire_once()
            if count:
                logger.info("rides.expired", extra={"count": count})
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("expiry_loop.failed")
        await asyncio.sleep(2.0)
