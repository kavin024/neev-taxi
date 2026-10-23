from __future__ import annotations

import pytest
from starlette.websockets import WebSocketDisconnect

from app.core.security import create_access_token


def test_websocket_connects_with_access_token(client, passenger):
    token, _ = create_access_token(passenger["id"], "passenger")
    with client.websocket_connect(f"/api/v1/ws?token={token}") as ws:
        ready = ws.receive_json()
        assert ready["type"] == "connection.ready"
        assert ready["payload"]["role"] == "passenger"
        assert ready["payload"]["heartbeat_seconds"] == 25

        ws.send_json({"action": "ping"})
        pong = ws.receive_json()
        assert pong["type"] == "pong"

        ws.send_json({"action": "subscribe", "ride_id": "not-a-real-ride"})
        denied = ws.receive_json()
        assert denied["type"] == "error"
        assert denied["payload"]["code"] == "forbidden"


def test_websocket_rejects_missing_or_bad_token(client):
    with pytest.raises(WebSocketDisconnect) as exc:
        with client.websocket_connect("/api/v1/ws") as ws:
            ws.receive_json()
    assert exc.value.code == 4401

    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect("/api/v1/ws?token=not-a-jwt") as ws:
            ws.receive_json()


def test_websocket_rejects_admin_token_on_passenger_socket(client, admin_headers):
    # An admin token has audience "admin" and must not authenticate the user socket.
    token = admin_headers["Authorization"].split(" ", 1)[1]
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect(f"/api/v1/ws?token={token}") as ws:
            ws.receive_json()
