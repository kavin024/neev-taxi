from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone
from typing import Iterable

from fastapi import WebSocket
from sqlalchemy.orm import Session

from app.models import RideEvent, RideRequest

logger = logging.getLogger("neev.realtime")


class ConnectionManager:
    def __init__(self) -> None:
        self._connections: dict[str, set[WebSocket]] = {}
        self._lock = asyncio.Lock()

    async def connect(self, user_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._connections.setdefault(user_id, set()).add(websocket)

    async def disconnect(self, user_id: str, websocket: WebSocket) -> None:
        async with self._lock:
            sockets = self._connections.get(user_id)
            if sockets:
                sockets.discard(websocket)
                if not sockets:
                    self._connections.pop(user_id, None)

    async def send_to_user(self, user_id: str, message: dict) -> int:
        async with self._lock:
            sockets = list(self._connections.get(user_id, set()))
        sent = 0
        for websocket in sockets:
            try:
                await websocket.send_json(message)
                sent += 1
            except Exception:
                await self.disconnect(user_id, websocket)
        return sent

    async def send_to_users(self, user_ids: Iterable[str], message: dict) -> int:
        unique = {uid for uid in user_ids if uid}
        results = await asyncio.gather(
            *(self.send_to_user(uid, message) for uid in unique), return_exceptions=True
        )
        return sum(r for r in results if isinstance(r, int))

    def connection_count(self) -> int:
        return sum(len(sockets) for sockets in self._connections.values())


manager = ConnectionManager()


def envelope(
    event_type: str,
    entity_id: str,
    payload: dict | None = None,
    *,
    event_id: int | str | None = None,
    created_at: datetime | None = None,
) -> dict:
    return {
        "event_id": event_id,
        "type": event_type,
        "entity_id": entity_id,
        "timestamp": (created_at or datetime.now(timezone.utc)).isoformat(),
        "payload": payload or {},
    }


def add_ride_event(
    db: Session,
    *,
    ride: RideRequest,
    event_type: str,
    payload: dict | None = None,
    trip_id: str | None = None,
    actor_user_id: str | None = None,
) -> RideEvent:
    event = RideEvent(
        ride_request_id=ride.id,
        trip_id=trip_id,
        event_type=event_type,
        actor_user_id=actor_user_id,
        payload=payload or {},
    )
    db.add(event)
    db.flush()
    return event


def event_envelope(event: RideEvent) -> dict:
    return envelope(
        event.event_type,
        event.ride_request_id,
        event.payload,
        event_id=event.id,
        created_at=event.created_at,
    )


async def broadcast_ride(
    db: Session, ride: RideRequest, event: RideEvent, *, extra_user_ids: Iterable[str] = ()
) -> None:
    recipients = {ride.passenger_id, ride.assigned_captain_id, *extra_user_ids}
    try:
        await manager.send_to_users(
            (uid for uid in recipients if uid), event_envelope(event)
        )
    except Exception:
        logger.warning("realtime.broadcast_failed", exc_info=True)


async def notify_user(
    db: Session,
    *,
    user_id: str,
    notification_type: str,
    title: str,
    body: str,
    data: dict | None = None,
) -> None:
    """In-app notification persisted then pushed. Delivery is best effort."""
    from app.models import Notification

    notification = Notification(
        user_id=user_id,
        type=notification_type,
        title=title,
        body=body,
        data=data or {},
    )
    db.add(notification)
    db.commit()
    try:
        await manager.send_to_user(
            user_id,
            envelope(
                "notification.created",
                notification.id,
                {
                    "id": notification.id,
                    "type": notification_type,
                    "title": title,
                    "body": body,
                    "data": data or {},
                },
            ),
        )
    except Exception:
        logger.warning("realtime.notification_push_failed", exc_info=True)
