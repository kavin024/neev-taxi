from __future__ import annotations

import hashlib
import os
import secrets
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, Request, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import api_error, get_captain, get_current_user, require_role
from app.core.config import settings
from app.core.database import get_db, utcnow
from app.core.security import create_access_token, decode_token
from app.models import (
    CaptainDocument,
    CaptainLocation,
    CaptainProfile,
    RideAssignment,
    RideRequest,
    ServiceArea,
    Trip,
    User,
    Vehicle,
)
from app.schemas.auth import (
    CaptainDraftBody,
    CaptainProfileUpdate,
    OnlineBody,
    VehicleBody,
)
from app.schemas.common import Message
from app.services.auth_service import serialize_user
from app.services.ledger_service import balance_paise
from app.services.ride_service import money, serialize_ride

router = APIRouter(prefix="/captain", tags=["captain"])

ALLOWED_DOC_TYPES = {
    "driving_license",
    "vehicle_rc",
    "insurance",
    "pan",
    "aadhaar",
    "profile_photo",
    "selfie",
}
MAGIC = {
    b"\xff\xd8\xff": ("image/jpeg", "jpg"),
    b"\x89PNG\r\n\x1a\n": ("image/png", "png"),
    b"%PDF": ("application/pdf", "pdf"),
}


def _sniff(data: bytes) -> tuple[str, str] | None:
    for prefix, result in MAGIC.items():
        if data.startswith(prefix):
            return result
    return None


@router.get("/profile")
def captain_profile(
    db: Session = Depends(get_db), user: User = Depends(require_role("captain"))
):
    profile = db.get(CaptainProfile, user.id)
    data = serialize_user(user, db)
    data["onboarding_required"] = profile is None
    if profile:
        data["profile"] = {
            "verification_status": profile.verification_status,
            "rejection_reason": profile.rejection_reason,
            "is_online": profile.is_online,
            "online_since": profile.online_since,
            "last_location_at": profile.last_location_at,
            "last_location_source": profile.last_location_source,
            "service_area_id": profile.service_area_id,
            "total_trips": profile.total_trips,
            "rating": profile.rating,
            "payout_upi_masked": (
                profile.payout_upi[:2] + "***" + profile.payout_upi.split("@")[-1]
                if profile.payout_upi and "@" in profile.payout_upi
                else None
            ),
        }
        data["documents"] = [
            {
                "id": d.id,
                "doc_type": d.doc_type,
                "status": d.status,
                "rejection_reason": d.rejection_reason,
                "original_filename": d.original_filename,
                "mime_type": d.mime_type,
                "size_bytes": d.size_bytes,
                "created_at": d.created_at,
            }
            for d in sorted(profile.documents, key=lambda d: d.created_at, reverse=True)
        ]
        data["vehicles"] = [
            {
                "id": v.id,
                "category": v.category,
                "reg_number": v.reg_number,
                "make_model": v.make_model,
                "color": v.color,
                "year": v.year,
                "is_active": v.is_active,
            }
            for v in profile.vehicles
        ]
        active = db.scalar(
            select(Trip).where(
                Trip.captain_id == user.id,
                Trip.state.in_(["captain_arriving", "arrived", "in_progress"]),
            )
        )
        if active:
            ride = db.get(RideRequest, active.ride_request_id)
            data["active_ride"] = serialize_ride(db, ride, viewer_role="captain")
    return data


@router.post("/onboarding", status_code=201)
def onboarding(
    body: CaptainDraftBody,
    db: Session = Depends(get_db),
    user: User = Depends(require_role("captain")),
):
    if db.get(CaptainProfile, user.id):
        raise api_error(409, "already_onboarded", "Captain profile already exists.")
    if body.service_area_id:
        area = db.get(ServiceArea, body.service_area_id)
        if not area or not area.is_active:
            raise api_error(400, "service_area_invalid", "Choose an active service area.")
    if body.pan_number and len(body.pan_number) != 10:
        raise api_error(422, "pan_invalid", "PAN must be 10 characters.")
    profile = CaptainProfile(
        user_id=user.id,
        name=body.name,
        email=body.email,
        dl_masked="***" + body.dl_number[-4:] if len(body.dl_number) > 4 else "***",
        pan_masked="******" + body.pan_number[-4:] if body.pan_number else None,
        aadhaar_masked="******" + body.aadhaar_last4 if body.aadhaar_last4 else None,
        service_area_id=body.service_area_id,
        verification_status="pending",
    )
    db.add(profile)
    db.commit()
    return {
        "user_id": user.id,
        "verification_status": "pending",
        "next": "Upload your driving licence, vehicle RC, insurance and a profile photo, then add your vehicle.",
        "documents_required": ["driving_license", "vehicle_rc", "insurance", "profile_photo"],
    }


@router.put("/profile")
def update_profile(
    body: CaptainProfileUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_captain),
):
    profile = db.get(CaptainProfile, user.id)
    for key, value in body.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(profile, key, value)
    db.commit()
    return serialize_user(user, db)


@router.post("/vehicles", status_code=201)
def add_vehicle(
    body: VehicleBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_captain),
):
    if db.scalar(select(Vehicle).where(Vehicle.reg_number == body.reg_number)):
        raise api_error(409, "vehicle_exists", "That registration number is already in use.")
    profile = db.get(CaptainProfile, user.id)
    if not profile.service_area_id:
        areas = db.scalars(select(ServiceArea).where(ServiceArea.is_active.is_(True))).all()
        if areas:
            profile.service_area_id = areas[0].id
    vehicle = Vehicle(captain_id=user.id, **body.model_dump())
    db.add(vehicle)
    db.commit()
    return {
        "id": vehicle.id,
        "category": vehicle.category,
        "reg_number": vehicle.reg_number,
        "make_model": vehicle.make_model,
    }


@router.delete("/vehicles/{vehicle_id}", response_model=Message)
def remove_vehicle(
    vehicle_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_captain),
):
    vehicle = db.get(Vehicle, vehicle_id)
    if not vehicle or vehicle.captain_id != user.id:
        raise api_error(404, "vehicle_not_found", "Vehicle not found.")
    active = db.scalar(
        select(Trip).where(
            Trip.captain_id == user.id,
            Trip.state.in_(["captain_arriving", "arrived", "in_progress"]),
        )
    )
    if active:
        raise api_error(409, "active_trip", "You cannot remove a vehicle during a trip.")
    db.delete(vehicle)
    db.commit()
    return Message(message="Vehicle removed.")


@router.post("/documents", status_code=201)
async def upload_document(
    doc_type: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_captain),
):
    if doc_type not in ALLOWED_DOC_TYPES:
        raise api_error(400, "document_type_invalid", "Unsupported document type.")
    data = await file.read(settings.max_upload_bytes + 1)
    if len(data) > settings.max_upload_bytes:
        raise api_error(413, "file_too_large", "Documents must be 10 MB or smaller.")
    sniffed = _sniff(data)
    if not sniffed:
        raise api_error(415, "file_type_invalid", "Upload a JPEG, PNG or PDF file.")
    mime, ext = sniffed
    if file.content_type and file.content_type not in {mime, "application/octet-stream"}:
        raise api_error(415, "mime_mismatch", "File contents do not match the declared type.")
    root = Path(settings.upload_dir).resolve()
    folder = root / user.id
    folder.mkdir(parents=True, exist_ok=True)
    key = f"{user.id}/{secrets.token_hex(16)}.{ext}"
    path = (root / key).resolve()
    if root not in path.parents:
        raise api_error(400, "path_invalid", "Invalid upload path.")
    path.write_bytes(data)
    doc = CaptainDocument(
        captain_id=user.id,
        doc_type=doc_type,
        storage_key=key,
        original_filename=os.path.basename(file.filename or f"document.{ext}")[:200],
        mime_type=mime,
        size_bytes=len(data),
        checksum=hashlib.sha256(data).hexdigest(),
        status="pending",
    )
    db.add(doc)
    profile = db.get(CaptainProfile, user.id)
    if profile and profile.verification_status == "rejected":
        profile.verification_status = "pending"
        profile.rejection_reason = None
    db.commit()
    return {
        "id": doc.id,
        "doc_type": doc.doc_type,
        "status": doc.status,
        "mime_type": doc.mime_type,
        "size_bytes": doc.size_bytes,
        "checksum": doc.checksum,
        "note": "Documents are private and reviewed manually by an admin.",
    }


@router.get("/documents/{document_id}/link")
def document_link(
    document_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_role("captain")),
):
    doc = db.get(CaptainDocument, document_id)
    if not doc or doc.captain_id != user.id:
        raise api_error(404, "document_not_found", "Document not found.")
    token, expires = create_access_token(
        user.id,
        "captain",
        extra={"typ": "document", "doc": doc.id},
    )
    return {
        "url": f"{settings.api_prefix}/captain/documents/{doc.id}/download?token={token}",
        "expires_at": expires,
    }


@router.get("/documents/{document_id}/download")
def document_download(document_id: str, token: str, db: Session = Depends(get_db)):
    doc = db.get(CaptainDocument, document_id)
    if not doc:
        raise api_error(404, "document_not_found", "Document not found.")
    try:
        payload = decode_token(token)
    except Exception:
        raise api_error(401, "link_expired", "This document link is invalid or has expired.")
    if payload.get("typ") != "document" or payload.get("doc") != doc.id:
        raise api_error(403, "link_forbidden", "This link is not valid for the document.")
    path = Path(settings.upload_dir).resolve() / doc.storage_key
    if not path.is_file():
        raise api_error(404, "file_missing", "Document file is unavailable.")
    return FileResponse(path, media_type=doc.mime_type, filename=doc.original_filename)


@router.post("/availability")
def set_availability(
    body: OnlineBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_captain),
):
    profile = db.get(CaptainProfile, user.id)
    if profile.verification_status != "approved":
        raise api_error(
            403,
            "captain_not_approved",
            "Your account must be approved before you can go online.",
            {"verification_status": profile.verification_status},
        )
    vehicle = db.scalar(
        select(Vehicle).where(Vehicle.captain_id == user.id, Vehicle.is_active.is_(True))
    )
    if body.is_online and not vehicle:
        raise api_error(403, "no_vehicle", "Add an active vehicle before going online.")
    if body.is_online:
        if body.lat is None or body.lng is None:
            raise api_error(400, "location_required", "Share your location to go online.")
        profile.is_online = True
        profile.online_since = profile.online_since or utcnow()
        profile.last_lat = body.lat
        profile.last_lng = body.lng
        profile.last_location_at = utcnow()
        profile.last_location_source = "gps"
        db.add(
            CaptainLocation(
                captain_id=user.id,
                lat=body.lat,
                lng=body.lng,
                source="gps",
                recorded_at=utcnow(),
            )
        )
    else:
        profile.is_online = False
        profile.online_since = None
    db.commit()
    return {
        "is_online": profile.is_online,
        "online_since": profile.online_since,
        "last_location_at": profile.last_location_at,
        "verification_status": profile.verification_status,
    }


@router.post("/location")
def idle_location(
    body: dict,
    db: Session = Depends(get_db),
    user: User = Depends(get_captain),
):
    profile = db.get(CaptainProfile, user.id)
    if not profile.is_online:
        raise api_error(409, "captain_offline", "Go online before sharing location.")
    try:
        lat = float(body["lat"])
        lng = float(body["lng"])
    except Exception:
        raise api_error(422, "invalid_location", "Valid lat and lng are required.")
    if not (-90 <= lat <= 90 and -180 <= lng <= 180):
        raise api_error(422, "invalid_location", "Coordinates out of range.")
    source = body.get("source", "gps")
    if source == "simulated" and not settings.dev_allow_gps_simulation:
        raise api_error(403, "simulation_disabled", "GPS simulation is disabled.")
    profile.last_lat = lat
    profile.last_lng = lng
    profile.last_location_at = utcnow()
    profile.last_location_source = source
    db.add(
        CaptainLocation(
            captain_id=user.id,
            lat=lat,
            lng=lng,
            source=source,
            recorded_at=utcnow(),
        )
    )
    db.commit()
    return {"accepted": True, "last_location_at": profile.last_location_at}


@router.get("/dashboard")
def captain_dashboard(
    db: Session = Depends(get_db), user: User = Depends(get_captain)
):
    profile = db.get(CaptainProfile, user.id)
    active = db.scalar(
        select(Trip).where(
            Trip.captain_id == user.id,
            Trip.state.in_(["captain_arriving", "arrived", "in_progress"]),
        )
    )
    active_ride = db.get(RideRequest, active.ride_request_id) if active else None
    offers = 0
    if profile.is_online:
        offers = len(
            db.execute(
                select(RideAssignment)
                .join(RideRequest, RideRequest.id == RideAssignment.ride_request_id)
                .where(
                    RideAssignment.captain_id == user.id,
                    RideAssignment.status == "offered",
                    RideAssignment.expires_at > utcnow(),
                    RideRequest.status == "searching",
                )
            ).all()
        )
    available = balance_paise(db, "captain_earnings", user.id)
    return {
        "profile": {
            "name": profile.name,
            "verification_status": profile.verification_status,
            "is_online": profile.is_online,
            "rating": profile.rating,
            "total_trips": profile.total_trips,
            "online_since": profile.online_since,
        },
        "offer_count": offers,
        "active_ride": serialize_ride(db, active_ride, viewer_role="captain")
        if active_ride
        else None,
        "earnings": {
            "available_paise": available,
            "available_display": money(available),
            "currency": "INR",
        },
        "documents_pending": len(
            [d for d in profile.documents if d.status == "pending"]
        ),
        "documents_rejected": len(
            [d for d in profile.documents if d.status == "rejected"]
        ),
    }
