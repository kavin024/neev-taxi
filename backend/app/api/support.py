from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import api_error, get_current_user
from app.core.database import get_db, utcnow
from app.models import SupportTicket, TicketMessage, User
from app.schemas.rides import SupportTicketBody, TicketReplyBody
from app.services.realtime import envelope, manager

router = APIRouter(prefix="/support", tags=["support"])


def serialize_ticket(t: SupportTicket, messages: list[TicketMessage] | None = None) -> dict:
    data = {
        "id": t.id,
        "category": t.category,
        "subject": t.subject,
        "description": t.description,
        "status": t.status,
        "priority": t.priority,
        "ride_request_id": t.ride_request_id,
        "resolution_notes": t.resolution_notes,
        "created_at": t.created_at,
        "updated_at": t.updated_at,
        "resolved_at": t.resolved_at,
    }
    if messages is not None:
        data["messages"] = [
            {
                "id": m.id,
                "sender_type": m.sender_type,
                "body": m.body,
                "created_at": m.created_at,
            }
            for m in messages
        ]
    return data


@router.post("/tickets", status_code=201)
async def create_ticket(
    body: SupportTicketBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if body.ride_request_id:
        from app.models import RideRequest

        ride = db.get(RideRequest, body.ride_request_id)
        if not ride or user.id not in {ride.passenger_id, ride.assigned_captain_id}:
            raise api_error(404, "ride_not_found", "Ride not found.")
    ticket = SupportTicket(
        user_id=user.id,
        ride_request_id=body.ride_request_id,
        category=body.category,
        subject=body.subject,
        description=body.description,
        status="open",
        priority="high" if body.category == "safety" else "normal",
    )
    db.add(ticket)
    db.flush()
    db.add(
        TicketMessage(
            ticket_id=ticket.id,
            sender_type="user",
            sender_id=user.id,
            body=body.description,
        )
    )
    db.commit()
    try:
        await manager.send_to_user(
            user.id,
            envelope(
                "support.ticket_updated",
                ticket.id,
                {"ticket_id": ticket.id, "status": ticket.status, "subject": ticket.subject},
            ),
        )
    except Exception:
        pass
    return serialize_ticket(ticket)


@router.get("/tickets")
def list_tickets(
    db: Session = Depends(get_db), user: User = Depends(get_current_user)
):
    rows = db.scalars(
        select(SupportTicket)
        .where(SupportTicket.user_id == user.id)
        .order_by(SupportTicket.created_at.desc())
        .limit(50)
    ).all()
    return [serialize_ticket(t) for t in rows]


@router.get("/tickets/{ticket_id}")
def get_ticket(
    ticket_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ticket = db.get(SupportTicket, ticket_id)
    if not ticket or ticket.user_id != user.id:
        raise api_error(404, "ticket_not_found", "Support ticket not found.")
    messages = db.scalars(
        select(TicketMessage)
        .where(TicketMessage.ticket_id == ticket.id)
        .order_by(TicketMessage.created_at)
    ).all()
    return serialize_ticket(ticket, messages)


@router.post("/tickets/{ticket_id}/messages", status_code=201)
async def reply_ticket(
    ticket_id: str,
    body: TicketReplyBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ticket = db.get(SupportTicket, ticket_id)
    if not ticket or ticket.user_id != user.id:
        raise api_error(404, "ticket_not_found", "Support ticket not found.")
    if ticket.status in {"resolved", "closed"}:
        raise api_error(409, "ticket_closed", "This ticket is closed. Open a new ticket if you need more help.")
    message = TicketMessage(
        ticket_id=ticket.id,
        sender_type="user",
        sender_id=user.id,
        body=body.body,
    )
    db.add(message)
    ticket.status = "open"
    ticket.updated_at = utcnow()
    db.commit()
    return {"id": message.id, "created_at": message.created_at}
