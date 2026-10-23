from __future__ import annotations

import json
from typing import Any

from sqlalchemy.orm import Session

from app.models import AuditLog

MAX_VALUE_CHARS = 4000


def _safe(value: Any) -> Any:
    if value is None:
        return None
    try:
        encoded = json.dumps(value, default=str)
    except Exception:
        return {"unserializable": True}
    if len(encoded) > MAX_VALUE_CHARS:
        return {"truncated": True, "preview": encoded[:MAX_VALUE_CHARS]}
    return json.loads(encoded)


def audit(
    db: Session,
    *,
    actor_type: str,
    actor_id: str | None,
    action: str,
    entity_type: str,
    entity_id: str | None,
    before: Any = None,
    after: Any = None,
    ip_address: str | None = None,
    request_id: str | None = None,
) -> None:
    db.add(
        AuditLog(
            actor_type=actor_type,
            actor_id=actor_id,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            before=_safe(before),
            after=_safe(after),
            ip_address=ip_address,
            request_id=request_id,
        )
    )
