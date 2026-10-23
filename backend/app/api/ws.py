from __future__ import annotations

import asyncio
import json
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy import select

from app.core.database import SessionLocal
from app.core.security import decode_token
from app.models import RideRequest, User
from app.services.realtime import envelope, manager

logger = logging.getLogger("neev.ws")
router = APIRouter(tags=["realtime"])


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = ""):
    if not token:
        await websocket.close(code=4401)
        return
    try:
        payload = decode_token(token)
        user_id = payload.get("sub")
    except Exception:
        await websocket.close(code=4401)
        return
    with SessionLocal() as db:
        user = db.get(User, user_id)
        if not user or user.status != "active" or int(payload.get("ver", 0)) != user.token_version:
            await websocket.close(code=4401)
            return
        role = user.role
    await manager.connect(user_id, websocket)
    try:
        await websocket.send_json(
            envelope(
                "connection.ready",
                user_id,
                {
                    "user_id": user_id,
                    "role": role,
                    "heartbeat_seconds": 25,
                    "note": "Fetch GET /rides/{id} after reconnecting to resynchronise missed events.",
                },
            )
        )
        while True:
            try:
                raw = await asyncio.wait_for(websocket.receive_text(), timeout=25)
            except asyncio.TimeoutError:
                await websocket.send_json(
                    envelope("heartbeat", user_id, {"server_time": None})
                )
                continue
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                await websocket.send_json(
                    envelope("error", user_id, {"code": "invalid_json"})
                )
                continue
            action = message.get("action")
            if action == "ping":
                await websocket.send_json(envelope("pong", user_id, {}))
            elif action == "subscribe":
                ride_id = message.get("ride_id")
                with SessionLocal() as db:
                    ride = db.get(RideRequest, ride_id)
                    allowed = bool(
                        ride
                        and user_id in {ride.passenger_id, ride.assigned_captain_id}
                    )
                await websocket.send_json(
                    envelope(
                        "subscription.ack" if allowed else "error",
                        ride_id or user_id,
                        {"subscribed": True}
                        if allowed
                        else {"code": "forbidden", "message": "Not a participant in that ride."},
                    )
                )
            else:
                await websocket.send_json(
                    envelope("error", user_id, {"code": "unknown_action"})
                )
    except WebSocketDisconnect:
        pass
    except Exception:
        logger.warning("ws.connection_error", exc_info=True)
    finally:
        await manager.disconnect(user_id, websocket)
