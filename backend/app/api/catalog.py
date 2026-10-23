from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import api_error, get_current_user, get_passenger, require_role
from app.core.config import settings
from app.core.database import get_db
from app.models import (
    PricingRule,
    SavedAddress,
    ServiceArea,
    ServiceCategory,
    TrustedContact,
    User,
    UserPowerPass,
)
from app.schemas.auth import SavedAddressBody, TrustedContactBody
from app.schemas.common import Message
from app.schemas.rides import PayoutRequestBody
from app.services.maps import get_map_provider
from app.services.payment_service import available_methods
from app.services.ride_service import money

router = APIRouter(tags=["catalog and locations"])


def public_pricing(db: Session, category: str) -> dict | None:
    rule = db.scalars(
        select(PricingRule)
        .where(PricingRule.category == category, PricingRule.is_active.is_(True))
        .order_by(PricingRule.effective_from.desc())
    ).first()
    if not rule:
        return None
    return {
        "base_fare_paise": rule.base_fare_paise,
        "base_fare_display": money(rule.base_fare_paise),
        "minimum_fare_paise": rule.minimum_fare_paise,
        "minimum_fare_display": money(rule.minimum_fare_paise),
        "per_km_paise": rule.per_km_paise,
        "per_km_display": money(rule.per_km_paise),
        "per_minute_paise": rule.per_minute_paise,
        "cancellation_fee_paise": rule.cancellation_fee_paise,
        "cancellation_fee_display": money(rule.cancellation_fee_paise),
        "currency": rule.currency,
        "version": rule.version,
    }


@router.get("/catalog/categories")
def categories(db: Session = Depends(get_db)):
    rows = db.scalars(
        select(ServiceCategory)
        .where(ServiceCategory.is_active.is_(True))
        .order_by(ServiceCategory.sort_order)
    ).all()
    return [
        {
            "code": c.code,
            "display_name": c.display_name,
            "description": c.description,
            "capacity": c.capacity,
            "icon": c.icon,
            "pricing": public_pricing(db, c.code),
        }
        for c in rows
    ]


@router.get("/catalog/config")
def app_config(db: Session = Depends(get_db)):
    areas = db.scalars(select(ServiceArea).where(ServiceArea.is_active.is_(True))).all()
    return {
        "brand": "Neev",
        "currency": "INR",
        "map": {
            "provider": settings.map_provider,
            "tile_url": settings.map_tile_url,
            "attribution": "© OpenStreetMap contributors",
            "demo_dataset": settings.map_provider == "demo",
            "note": "Demo locations use real Bengaluru coordinates from a local fixture."
            if settings.map_provider == "demo"
            else "Development map data. Configure a production map provider before launch.",
        },
        "payments": available_methods(),
        "payment_provider": settings.payment_provider,
        "sandbox_payments": settings.payment_provider == "sandbox" and settings.is_dev,
        "gps_simulation": settings.dev_allow_gps_simulation,
        "service_areas": [
            {
                "id": a.id,
                "name": a.name,
                "city": a.city,
                "center": {"lat": a.center_lat, "lng": a.center_lng},
                "radius_km": a.radius_km,
            }
            for a in areas
        ],
        "dispatch_radius_km": settings.dispatch_radius_km,
        "support_phone_note": "In-app support only in this build. No emergency service integration is active.",
    }


@router.get("/locations/search")
def search_locations(q: str = Query(min_length=1, max_length=160), db: Session = Depends(get_db)):
    provider = get_map_provider()
    results = provider.search(q)
    return {
        "provider": provider.name,
        "demo_dataset": provider.name == "demo",
        "results": [p.__dict__ for p in results],
    }


@router.get("/locations/reverse")
def reverse_location(lat: float = Query(ge=-90, le=90), lng: float = Query(ge=-180, le=180)):
    provider = get_map_provider()
    place = provider.reverse(lat, lng)
    return {"provider": provider.name, "place": place.__dict__}


@router.get("/locations/service-areas")
def service_areas(db: Session = Depends(get_db)):
    areas = db.scalars(select(ServiceArea).where(ServiceArea.is_active.is_(True))).all()
    return [
        {
            "id": a.id,
            "name": a.name,
            "city": a.city,
            "center_lat": a.center_lat,
            "center_lng": a.center_lng,
            "radius_km": a.radius_km,
        }
        for a in areas
    ]


@router.get("/passenger/saved-addresses")
def list_saved(
    db: Session = Depends(get_db), user: User = Depends(get_passenger)
):
    rows = db.scalars(
        select(SavedAddress).where(SavedAddress.user_id == user.id).order_by(SavedAddress.created_at.desc())
    ).all()
    return [
        {"id": r.id, "label": r.label, "address": r.address, "lat": r.lat, "lng": r.lng}
        for r in rows
    ]


@router.post("/passenger/saved-addresses", status_code=201)
def add_saved(
    body: SavedAddressBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_passenger),
):
    if db.scalar(select(SavedAddress).where(SavedAddress.user_id == user.id, SavedAddress.label == body.label)):
        raise api_error(409, "duplicate_label", "You already have a saved place with that label.")
    row = SavedAddress(user_id=user.id, **body.model_dump())
    db.add(row)
    db.commit()
    return {"id": row.id, **body.model_dump()}


@router.delete("/passenger/saved-addresses/{address_id}", response_model=Message)
def delete_saved(
    address_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_passenger),
):
    row = db.get(SavedAddress, address_id)
    if not row or row.user_id != user.id:
        raise api_error(404, "address_not_found", "Saved place not found.")
    db.delete(row)
    db.commit()
    return Message(message="Saved place removed.")


@router.get("/passenger/trusted-contacts")
def list_contacts(db: Session = Depends(get_db), user: User = Depends(get_passenger)):
    rows = db.scalars(
        select(TrustedContact).where(TrustedContact.user_id == user.id).order_by(TrustedContact.created_at)
    ).all()
    return [
        {"id": r.id, "name": r.name, "phone": r.phone, "relationship": r.relationship}
        for r in rows
    ]


@router.post("/passenger/trusted-contacts", status_code=201)
def add_contact(
    body: TrustedContactBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_passenger),
):
    count = len(db.scalars(select(TrustedContact).where(TrustedContact.user_id == user.id)).all())
    if count >= 5:
        raise api_error(400, "contact_limit", "You can save up to five trusted contacts.")
    row = TrustedContact(user_id=user.id, **body.model_dump())
    db.add(row)
    db.commit()
    return {"id": row.id, **body.model_dump()}


@router.delete("/passenger/trusted-contacts/{contact_id}", response_model=Message)
def delete_contact(
    contact_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_passenger),
):
    row = db.get(TrustedContact, contact_id)
    if not row or row.user_id != user.id:
        raise api_error(404, "contact_not_found", "Trusted contact not found.")
    db.delete(row)
    db.commit()
    return Message(message="Trusted contact removed.")
