from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db, utcnow
from app.models import Notification, User
from app.schemas.rides import NotificationReadBody

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("")
def list_notifications(
    unread_only: bool = False,
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    stmt = select(Notification).where(Notification.user_id == user.id)
    if unread_only:
        stmt = stmt.where(Notification.read_at.is_(None))
    rows = db.scalars(stmt.order_by(Notification.created_at.desc()).limit(limit)).all()
    unread = db.scalar(
        select(func.count(Notification.id)).where(
            Notification.user_id == user.id, Notification.read_at.is_(None)
        )
    ) or 0
    return {
        "items": [
            {
                "id": n.id,
                "type": n.type,
                "title": n.title,
                "body": n.body,
                "data": n.data,
                "read_at": n.read_at,
                "created_at": n.created_at,
            }
            for n in rows
        ],
        "unread_count": unread,
    }


@router.post("/read")
def mark_read(
    body: NotificationReadBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    stmt = update(Notification).where(Notification.user_id == user.id)
    if body.notification_ids:
        stmt = stmt.where(Notification.id.in_(body.notification_ids))
    else:
        stmt = stmt.where(Notification.read_at.is_(None))
    result = db.execute(stmt.values(read_at=utcnow()))
    db.commit()
    return {"updated": result.rowcount}
