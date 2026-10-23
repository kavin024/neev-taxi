from __future__ import annotations

from datetime import timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import api_error, get_current_user
from app.core.config import settings
from app.core.database import get_db, utcnow
from app.integrations.sms import send_sms
from app.models import RideRequest, SafetyIncident, TrustedContact, User
from app.schemas.common import Message
from app.schemas.rides import SosBody
from app.services.audit_service import audit
from app.services.realtime import notify_user

router = APIRouter(prefix="/safety", tags=["safety"])


@router.get("/features")
def safety_features():
    return {
        "features": [
            {
                "code": "trip_pin",
                "title": "4-digit start PIN",
                "description": "Share the PIN with your captain only when you are ready to start.",
                "available": True,
            },
            {
                "code": "live_tracking",
                "title": "Live trip tracking",
                "description": "Authorised trip participants can view captain location updates.",
                "available": True,
            },
            {
                "code": "share_trip",
                "title": "Share live trip",
                "description": "Create an unlisted, expiring link with limited trip details.",
                "available": True,
            },
            {
                "code": "sos",
                "title": "In-app SOS record",
                "description": "Creates an incident record and queues messages in the configured SMS adapter.",
                "available": True,
                "important": "This build has no emergency-services or 24x7 safety-desk integration. Call local emergency services directly if you are in danger.",
            },
            {
                "code": "insurance",
                "title": "In-ride insurance",
                "description": "Not included in this independent build.",
                "available": False,
            },
        ],
        "emergency_number": "112",
        "disclaimer": "Neev is a development build. SOS does not contact police, ambulances, or a staffed safety desk.",
    }


@router.post("/sos", status_code=201)
async def activate_sos(
    body: SosBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if body.press_hold_ms < 3000:
        raise api_error(400, "sos_hold_too_short", "Press and hold SOS for at least three seconds.")
    now = utcnow()
    cooldown_start = now - timedelta(minutes=settings.sos_cooldown_minutes)
    recent = db.scalar(
        select(SafetyIncident).where(
            SafetyIncident.user_id == user.id,
            SafetyIncident.created_at >= cooldown_start,
            SafetyIncident.status != "cancelled",
        )
    )
    if recent:
        raise api_error(
            429,
            "sos_cooldown",
            "An SOS incident was recently created. Use the existing incident or call emergency services directly.",
            {"incident_id": recent.id},
        )
    ride = None
    if body.ride_request_id:
        ride = db.get(RideRequest, body.ride_request_id)
        if not ride or user.id not in {ride.passenger_id, ride.assigned_captain_id}:
            raise api_error(404, "ride_not_found", "Ride not found for this SOS.")
    incident = SafetyIncident(
        user_id=user.id,
        ride_request_id=ride.id if ride else None,
        trip_id=ride.trip.id if ride and ride.trip else None,
        incident_type="sos",
        lat=body.lat,
        lng=body.lng,
        status="active",
        note=body.note,
    )
    db.add(incident)
    db.flush()

    contacts = db.scalars(
        select(TrustedContact).where(TrustedContact.user_id == user.id)
    ).all()
    delivered = 0
    queued = 0
    for contact in contacts:
        delivery, _ = send_sms(
            db,
            recipient=contact.phone,
            template="sos_alert",
            body=(
                f"Neev SOS: {user.phone[-4:].rjust(4, '*')} triggered an in-app safety alert. "
                f"Location: {body.lat}, {body.lng}. This development build does not contact emergency services. "
                f"Try calling them directly."
            ),
        )
        if delivery == "outbox_simulated":
            queued += 1
        elif delivery == "sms":
            delivered += 1
    incident.contacts_notified = delivered
    incident.emergency_services_contacted = False
    audit(
        db,
        actor_type=user.role,
        actor_id=user.id,
        action="safety.sos_created",
        entity_type="safety_incident",
        entity_id=incident.id,
        after={"status": "active", "delivered": delivered, "queued": queued},
    )
    db.commit()
    await notify_user(
        db,
        user_id=user.id,
        notification_type="safety.sos",
        title="SOS record created",
        body=(
            "Your incident was recorded. Emergency services were NOT contacted by this build. "
            "Call 112 if you are in danger."
        ),
        data={"incident_id": incident.id},
    )
    return {
        "incident_id": incident.id,
        "status": incident.status,
        "created_at": incident.created_at,
        "contacts_available": len(contacts),
        "contacts_delivered": delivered,
        "contacts_queued_simulated": queued,
        "emergency_services_contacted": False,
        "safety_team_notified": False,
        "provider": settings.sms_provider,
        "provider_mode": "simulated"
        if settings.sms_provider == "outbox"
        else "configured",
        "disclaimer": "No emergency service or staffed safety desk was contacted. Call local emergency services if needed.",
        "cancel_window_seconds": 120,
    }


@router.post("/sos/{incident_id}/cancel")
async def cancel_sos(
    incident_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    incident = db.get(SafetyIncident, incident_id)
    if not incident or incident.user_id != user.id:
        raise api_error(404, "incident_not_found", "SOS incident not found.")
    if incident.status != "active":
        raise api_error(409, "incident_not_active", "This incident is no longer active.")
    if utcnow() - incident.created_at > timedelta(minutes=2):
        raise api_error(
            409,
            "cancel_window_closed",
            "The two-minute cancellation window has closed. Contact support to resolve the incident.",
        )
    incident.status = "cancelled"
    incident.cancelled_at = utcnow()
    audit(
        db,
        actor_type=user.role,
        actor_id=user.id,
        action="safety.sos_cancelled",
        entity_type="safety_incident",
        entity_id=incident.id,
        after={"status": "cancelled"},
    )
    db.commit()
    return {"incident_id": incident.id, "status": incident.status, "message": "SOS cancelled as a false alarm."}


@router.get("/sos/active")
def active_sos(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    incident = db.scalar(
        select(SafetyIncident)
        .where(SafetyIncident.user_id == user.id, SafetyIncident.status == "active")
        .order_by(SafetyIncident.created_at.desc())
    )
    if not incident:
        return {"active": None}
    return {
        "active": {
            "id": incident.id,
            "created_at": incident.created_at,
            "lat": incident.lat,
            "lng": incident.lng,
            "contacts_notified": incident.contacts_notified,
            "emergency_services_contacted": False,
        }
    }


@router.get("/sos/history")
def sos_history(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    rows = db.scalars(
        select(SafetyIncident)
        .where(SafetyIncident.user_id == user.id)
        .order_by(SafetyIncident.created_at.desc())
        .limit(50)
    ).all()
    return [
        {
            "id": r.id,
            "status": r.status,
            "ride_request_id": r.ride_request_id,
            "created_at": r.created_at,
            "cancelled_at": r.cancelled_at,
            "resolved_at": r.resolved_at,
            "contacts_notified": r.contacts_notified,
            "emergency_services_contacted": r.emergency_services_contacted,
        }
        for r in rows
    ]
