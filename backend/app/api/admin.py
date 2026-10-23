from __future__ import annotations

import csv
import io
from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Query, Request, Response
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.api.deps import (
    api_error,
    get_admin,
    require_admin_role,
)
from app.core.database import get_db, utcnow
from app.core.rate_limit import rate_limit
from app.core.security import create_access_token, new_opaque_token
from app.models import (
    AdminUser,
    AppSetting,
    AuditLog,
    CaptainDocument,
    CaptainProfile,
    Coupon,
    LedgerEntry,
    PaymentTransaction,
    PayoutRequest,
    PowerPassPlan,
    PricingRule,
    Refund,
    RideRequest,
    SafetyIncident,
    ServiceArea,
    ServiceCategory,
    SupportTicket,
    TicketMessage,
    Trip,
    User,
    Vehicle,
)
from app.schemas.admin import (
    AdminCreate,
    CategoryUpdate,
    CouponCreate,
    CouponUpdate,
    PayoutDecision,
    PowerPassUpdate,
    PricingCreate,
    PricingUpdate,
    RefundDecision,
    ServiceAreaCreate,
    ServiceAreaUpdate,
    SettingUpdate,
    TicketResolve,
)
from app.schemas.auth import AdminLoginBody, CaptainDecisionBody, SuspendBody
from app.schemas.common import Message
from app.schemas.rides import TicketReplyBody
from app.services.audit_service import audit
from app.services.auth_service import admin_login, create_admin, serialize_user
from app.services.ledger_service import reverse_payout_hold
from app.services.payment_service import decide_refund
from app.services.realtime import manager
from app.services.realtime import envelope
from app.services.ride_service import money, serialize_ride, serialize_offer
from app.services.security_utils import masked_phone

router = APIRouter(prefix="/admin", tags=["admin"])


def admin_dict(admin: AdminUser) -> dict:
    return {
        "id": admin.id,
        "email": admin.email,
        "name": admin.name,
        "role": admin.role,
        "is_active": admin.is_active,
        "last_login_at": admin.last_login_at,
    }


def admin_audit(
    db: Session,
    admin: AdminUser,
    request: Request,
    action: str,
    entity_type: str,
    entity_id: str | None,
    before=None,
    after=None,
):
    audit(
        db,
        actor_type="admin",
        actor_id=admin.id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        before=before,
        after=after,
        ip_address=request.client.host if request.client else None,
        request_id=getattr(request.state, "request_id", None),
    )


@router.post("/auth/login", dependencies=[Depends(rate_limit("admin_login", 10, 600))])
def login(body: AdminLoginBody, db: Session = Depends(get_db)):
    admin, token, expires_in = admin_login(db, body.email, body.password)
    return {"access_token": token, "token_type": "bearer", "expires_in": expires_in, "admin": admin_dict(admin)}


@router.get("/auth/me")
def me(admin: AdminUser = Depends(get_admin)):
    return admin_dict(admin)


@router.get("/dashboard")
def dashboard(
    days: int = Query(7, ge=1, le=90),
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    now = utcnow()
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    since = today - timedelta(days=days - 1)

    rides_today = db.scalar(
        select(func.count(RideRequest.id)).where(RideRequest.created_at >= today)
    ) or 0
    completed_today = db.scalar(
        select(func.count(Trip.id)).where(Trip.state == "completed", Trip.completed_at >= today)
    ) or 0
    active_rides = db.scalar(
        select(func.count(Trip.id)).where(
            Trip.state.in_(["captain_arriving", "arrived", "in_progress"])
        )
    ) or 0
    online_captains = db.scalar(
        select(func.count(CaptainProfile.user_id)).where(
            CaptainProfile.is_online.is_(True),
            CaptainProfile.verification_status == "approved",
        )
    ) or 0
    pending_approvals = db.scalar(
        select(func.count(CaptainProfile.user_id)).where(
            CaptainProfile.verification_status == "pending"
        )
    ) or 0
    open_tickets = db.scalar(
        select(func.count(SupportTicket.id)).where(SupportTicket.status.in_(["open", "pending"]))
    ) or 0
    payments_today = db.scalars(
        select(PaymentTransaction).where(
            PaymentTransaction.status == "captured", PaymentTransaction.created_at >= today
        )
    ).all()
    revenue_today = sum(p.amount_paise for p in payments_today)
    commission_today = db.scalar(
        select(func.coalesce(func.sum(LedgerEntry.amount_paise), 0)).where(
            LedgerEntry.entry_type == "trip_commission",
            LedgerEntry.created_at >= today,
        )
    ) or 0

    ride_rows = db.execute(
        select(RideRequest.created_at, RideRequest.category, RideRequest.quoted_fare_paise).where(
            RideRequest.created_at >= since
        )
    ).all()
    series: dict[str, dict] = {}
    for i in range(days):
        day = (since + timedelta(days=i)).date().isoformat()
        series[day] = {"date": day, "rides": 0, "gmv_paise": 0}
    categories: dict[str, int] = {}
    for created_at, category, fare in ride_rows:
        key = created_at.date().isoformat()
        if key in series:
            series[key]["rides"] += 1
            series[key]["gmv_paise"] += fare or 0
        categories[category] = categories.get(category, 0) + 1

    return {
        "kpis": {
            "rides_today": rides_today,
            "completed_today": completed_today,
            "active_rides": active_rides,
            "online_captains": online_captains,
            "pending_captain_approvals": pending_approvals,
            "open_tickets": open_tickets,
            "captured_payments_today_paise": revenue_today,
            "captured_payments_today_display": money(revenue_today),
            "platform_commission_today_paise": commission_today,
            "platform_commission_today_display": money(commission_today),
        },
        "ride_series": list(series.values()),
        "category_breakdown": [
            {"category": k, "rides": v} for k, v in sorted(categories.items())
        ],
        "demo_data_present": bool(
            db.scalar(select(func.count(User.id)).where(User.is_demo.is_(True)))
        ),
        "generated_at": now,
        "sources": "Live aggregate queries against the Neev PostgreSQL database.",
    }


@router.get("/passengers")
def passengers(
    search: str | None = None,
    status: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(25, ge=1, le=100),
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    stmt = select(User).where(User.role == "passenger")
    if search:
        like = f"%{search.strip()}%"
        stmt = stmt.where(or_(User.phone.ilike(like), User.id.ilike(like)))
    if status:
        stmt = stmt.where(User.status == status)
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(
        stmt.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    ).all()
    return {
        "items": [
            {
                "id": u.id,
                "phone": u.phone,
                "masked_phone": masked_phone(u.phone),
                "name": u.passenger_profile.name if u.passenger_profile else None,
                "status": u.status,
                "is_demo": u.is_demo,
                "phone_verified": u.phone_verified,
                "total_rides": u.passenger_profile.total_rides if u.passenger_profile else 0,
                "rating": (
                    round(u.passenger_profile.rating_sum / u.passenger_profile.rating_count, 2)
                    if u.passenger_profile and u.passenger_profile.rating_count
                    else None
                ),
                "created_at": u.created_at,
                "last_login_at": u.last_login_at,
            }
            for u in rows
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/passengers/{user_id}")
def passenger_detail(
    user_id: str,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    user = db.get(User, user_id)
    if not user or user.role != "passenger":
        raise api_error(404, "passenger_not_found", "Passenger not found.")
    rides = db.scalars(
        select(RideRequest)
        .where(RideRequest.passenger_id == user.id)
        .order_by(RideRequest.created_at.desc())
        .limit(50)
    ).all()
    return {
        **serialize_user(user, db),
        "rides": [serialize_ride(db, r, viewer_role="passenger") for r in rides],
        "tickets": [
            {
                "id": t.id,
                "subject": t.subject,
                "status": t.status,
                "created_at": t.created_at,
            }
            for t in db.scalars(
                select(SupportTicket).where(SupportTicket.user_id == user.id).limit(20)
            ).all()
        ],
    }


@router.post("/passengers/{user_id}/status")
async def passenger_status(
    user_id: str,
    body: SuspendBody,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    user = db.get(User, user_id)
    if not user or user.role != "passenger":
        raise api_error(404, "passenger_not_found", "Passenger not found.")
    before = {"status": user.status}
    user.status = "suspended" if body.suspended else "active"
    if body.suspended:
        user.token_version += 1
    admin_audit(
        db, admin, request,
        "passenger.suspend" if body.suspended else "passenger.reinstate",
        "user", user.id, before, {"status": user.status, "reason": body.reason},
    )
    db.commit()
    if body.suspended:
        await manager.send_to_user(user.id, envelope("account.updated", user.id, {"status": "suspended"}))
    return {"id": user.id, "status": user.status}


@router.get("/captains")
def captains(
    search: str | None = None,
    verification_status: str | None = None,
    is_online: bool | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(25, ge=1, le=100),
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    stmt = (
        select(CaptainProfile)
        .join(User, User.id == CaptainProfile.user_id)
        .where(User.role == "captain")
    )
    if search:
        like = f"%{search.strip()}%"
        stmt = stmt.where(or_(CaptainProfile.name.ilike(like), User.phone.ilike(like)))
    if verification_status:
        stmt = stmt.where(CaptainProfile.verification_status == verification_status)
    if is_online is not None:
        stmt = stmt.where(CaptainProfile.is_online.is_(is_online))
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(
        stmt.order_by(CaptainProfile.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    items = []
    for c in rows:
        user = db.get(User, c.user_id)
        vehicle = db.scalar(select(Vehicle).where(Vehicle.captain_id == c.user_id))
        items.append(
            {
                "id": c.user_id,
                "name": c.name,
                "phone": masked_phone(user.phone) if user else "—",
                "status": user.status if user else "unknown",
                "verification_status": c.verification_status,
                "is_online": c.is_online,
                "rating": c.rating,
                "total_trips": c.total_trips,
                "category": vehicle.category if vehicle else None,
                "vehicle": vehicle.reg_number if vehicle else None,
                "pending_documents": len([d for d in c.documents if d.status == "pending"]),
                "is_demo": user.is_demo if user else False,
                "created_at": c.created_at,
            }
        )
    return {"items": items, "total": total, "page": page, "page_size": page_size}


@router.get("/captains/{captain_id}")
def captain_detail(
    captain_id: str,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    c = db.get(CaptainProfile, captain_id)
    user = db.get(User, captain_id)
    if not c or not user:
        raise api_error(404, "captain_not_found", "Captain not found.")
    earnings = db.scalar(
        select(func.coalesce(func.sum(LedgerEntry.amount_paise), 0)).where(
            LedgerEntry.user_id == c.user_id,
            LedgerEntry.account_type == "captain_earnings",
            LedgerEntry.entry_type == "trip_earning",
        )
    ) or 0
    trips = db.scalars(
        select(Trip).where(Trip.captain_id == c.user_id).order_by(Trip.created_at.desc()).limit(50)
    ).all()
    return {
        "id": c.user_id,
        "name": c.name,
        "phone": user.phone,
        "email": c.email,
        "status": user.status,
        "verification_status": c.verification_status,
        "rejection_reason": c.rejection_reason,
        "is_online": c.is_online,
        "rating": c.rating,
        "total_trips": c.total_trips,
        "dl_masked": c.dl_masked,
        "pan_masked": c.pan_masked,
        "aadhaar_masked": c.aadhaar_masked,
        "lifetime_earnings_paise": earnings,
        "lifetime_earnings_display": money(earnings),
        "is_demo": user.is_demo,
        "created_at": c.created_at,
        "approved_at": c.approved_at,
        "documents": [
            {
                "id": d.id,
                "doc_type": d.doc_type,
                "status": d.status,
                "original_filename": d.original_filename,
                "mime_type": d.mime_type,
                "size_bytes": d.size_bytes,
                "rejection_reason": d.rejection_reason,
                "created_at": d.created_at,
            }
            for d in c.documents
        ],
        "vehicles": [
            {
                "id": v.id,
                "category": v.category,
                "reg_number": v.reg_number,
                "make_model": v.make_model,
                "color": v.color,
                "year": v.year,
                "is_active": v.is_active,
            }
            for v in c.vehicles
        ],
        "trips": [
            {
                "id": t.id,
                "ride_id": t.ride_request_id,
                "state": t.state,
                "completed_at": t.completed_at,
                "final_fare_paise": t.final_fare_paise,
                "payment_status": t.payment_status,
            }
            for t in trips
        ],
    }


@router.post("/captains/{captain_id}/decision")
async def captain_decision(
    captain_id: str,
    body: CaptainDecisionBody,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    c = db.get(CaptainProfile, captain_id)
    user = db.get(User, captain_id)
    if not c or not user:
        raise api_error(404, "captain_not_found", "Captain not found.")
    if body.approved:
        required = {"driving_license", "vehicle_rc", "insurance", "profile_photo"}
        present = {d.doc_type for d in c.documents if d.status != "rejected"}
        missing = sorted(required - present)
        if not c.vehicles:
            missing.append("vehicle")
        if missing:
            raise api_error(
                409,
                "documents_missing",
                "Captain cannot be approved until required documents and a vehicle are on file.",
                {"missing": missing},
            )
        before = {"verification_status": c.verification_status}
        c.verification_status = "approved"
        c.rejection_reason = None
        c.approved_at = utcnow()
        c.approved_by = admin.id
        for doc in c.documents:
            if doc.status == "pending":
                doc.status = "approved"
                doc.reviewed_by = admin.id
                doc.reviewed_at = utcnow()
        admin_audit(db, admin, request, "captain.approve", "captain_profile", c.user_id, before, {"verification_status": "approved"})
        db.commit()
        await manager.send_to_user(user.id, envelope("captain.verification_updated", user.id, {"verification_status": "approved"}))
        return {"id": c.user_id, "verification_status": c.verification_status}
    if not body.reason or len(body.reason.strip()) < 5:
        raise api_error(400, "reason_required", "Give a clear rejection reason for the captain.")
    before = {"verification_status": c.verification_status}
    c.verification_status = "rejected"
    c.rejection_reason = body.reason.strip()
    c.is_online = False
    admin_audit(db, admin, request, "captain.reject", "captain_profile", c.user_id, before, {"reason": c.rejection_reason})
    db.commit()
    await manager.send_to_user(user.id, envelope("captain.verification_updated", user.id, {"verification_status": "rejected", "reason": c.rejection_reason}))
    return {"id": c.user_id, "verification_status": c.verification_status, "reason": c.rejection_reason}


@router.post("/captains/{captain_id}/documents/{document_id}/review")
async def review_document(
    captain_id: str,
    document_id: str,
    body: dict,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    doc = db.get(CaptainDocument, document_id)
    if not doc or doc.captain_id != captain_id:
        raise api_error(404, "document_not_found", "Document not found.")
    approved = bool(body.get("approved"))
    reason = body.get("reason")
    if not approved and (not reason or len(str(reason)) < 5):
        raise api_error(400, "reason_required", "Explain why the document was rejected.")
    before = {"status": doc.status}
    doc.status = "approved" if approved else "rejected"
    doc.rejection_reason = None if approved else reason
    doc.reviewed_by = admin.id
    doc.reviewed_at = utcnow()
    profile = db.get(CaptainProfile, captain_id)
    if profile and not approved:
        profile.verification_status = "pending"
    admin_audit(db, admin, request, "document.review", "captain_document", doc.id, before, {"status": doc.status, "reason": reason})
    db.commit()
    return {"id": doc.id, "status": doc.status}


@router.get("/documents/{document_id}/link")
def admin_document_link(
    document_id: str,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    doc = db.get(CaptainDocument, document_id)
    if not doc:
        raise api_error(404, "document_not_found", "Document not found.")
    token, expires = create_access_token(
        admin.id, admin.role, extra={"typ": "document", "doc": doc.id}
    )
    return {
        "url": f"/api/v1/captain/documents/{doc.id}/download?token={token}",
        "expires_at": expires,
        "document": {
            "doc_type": doc.doc_type,
            "original_filename": doc.original_filename,
            "status": doc.status,
        },
    }


@router.post("/captains/{captain_id}/status")
async def captain_status(
    captain_id: str,
    body: SuspendBody,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    c = db.get(CaptainProfile, captain_id)
    user = db.get(User, captain_id)
    if not c or not user:
        raise api_error(404, "captain_not_found", "Captain not found.")
    before = {"status": user.status, "verification_status": c.verification_status}
    if body.suspended:
        user.status = "suspended"
        user.token_version += 1
        c.verification_status = "suspended"
        c.is_online = False
    else:
        user.status = "active"
        c.verification_status = "approved"
    admin_audit(
        db, admin, request,
        "captain.suspend" if body.suspended else "captain.reinstate",
        "user", user.id, before, {"status": user.status, "reason": body.reason},
    )
    db.commit()
    await manager.send_to_user(user.id, envelope("account.updated", user.id, {"status": user.status}))
    return {"id": user.id, "status": user.status, "verification_status": c.verification_status}


@router.get("/rides")
def rides(
    status: str | None = None,
    category: str | None = None,
    from_date: datetime | None = None,
    to_date: datetime | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(25, ge=1, le=100),
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    stmt = select(RideRequest)
    if status:
        stmt = stmt.where(RideRequest.status == status)
    if category:
        stmt = stmt.where(RideRequest.category == category)
    if from_date:
        stmt = stmt.where(RideRequest.created_at >= from_date)
    if to_date:
        stmt = stmt.where(RideRequest.created_at <= to_date)
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(
        stmt.order_by(RideRequest.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return {
        "items": [
            {
                "id": r.id,
                "category": r.category,
                "status": r.status,
                "pickup": r.pickup_address,
                "drop": r.drop_address,
                "fare_paise": r.quoted_fare_paise,
                "fare_display": money(r.quoted_fare_paise),
                "passenger_id": r.passenger_id,
                "captain_id": r.assigned_captain_id,
                "trip_state": r.trip.state if r.trip else None,
                "created_at": r.created_at,
            }
            for r in rows
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/rides/{ride_id}")
def ride_detail(
    ride_id: str,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    ride = db.get(RideRequest, ride_id)
    if not ride:
        raise api_error(404, "ride_not_found", "Ride not found.")
    return serialize_ride(db, ride, viewer_role="admin", include_events=True)


@router.get("/pricing")
def list_pricing(db: Session = Depends(get_db), admin: AdminUser = Depends(get_admin)):
    rows = db.scalars(select(PricingRule).order_by(PricingRule.category, PricingRule.effective_from.desc())).all()
    return [
        {
            "id": r.id,
            "category": r.category,
            "service_area_id": r.service_area_id,
            "base_fare_paise": r.base_fare_paise,
            "minimum_fare_paise": r.minimum_fare_paise,
            "per_km_paise": r.per_km_paise,
            "per_minute_paise": r.per_minute_paise,
            "waiting_per_minute_paise": r.waiting_per_minute_paise,
            "cancellation_fee_paise": r.cancellation_fee_paise,
            "platform_fee_paise": r.platform_fee_paise,
            "commission_pct": r.commission_pct,
            "night_multiplier": r.night_multiplier,
            "version": r.version,
            "is_active": r.is_active,
            "effective_from": r.effective_from,
        }
        for r in rows
    ]


@router.post("/pricing", status_code=201)
def create_pricing(
    body: PricingCreate,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    rule = PricingRule(**body.model_dump(), version=1)
    db.add(rule)
    db.flush()
    admin_audit(db, admin, request, "pricing.create", "pricing_rule", rule.id, None, body.model_dump())
    db.commit()
    return {"id": rule.id}


@router.patch("/pricing/{rule_id}")
def update_pricing(
    rule_id: str,
    body: PricingUpdate,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    rule = db.get(PricingRule, rule_id)
    if not rule:
        raise api_error(404, "pricing_not_found", "Pricing rule not found.")
    before = {k: getattr(rule, k) for k in body.model_dump(exclude_unset=True)}
    for key, value in body.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(rule, key, value)
    rule.version += 1
    admin_audit(db, admin, request, "pricing.update", "pricing_rule", rule.id, before, body.model_dump(exclude_unset=True))
    db.commit()
    return {"id": rule.id, "version": rule.version}


@router.get("/categories")
def list_categories(db: Session = Depends(get_db), admin: AdminUser = Depends(get_admin)):
    rows = db.scalars(select(ServiceCategory).order_by(ServiceCategory.sort_order)).all()
    return [
        {
            "id": c.id,
            "code": c.code,
            "display_name": c.display_name,
            "description": c.description,
            "capacity": c.capacity,
            "is_active": c.is_active,
            "sort_order": c.sort_order,
        }
        for c in rows
    ]


@router.patch("/categories/{category_id}")
def update_category(
    category_id: str,
    body: CategoryUpdate,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    category = db.get(ServiceCategory, category_id)
    if not category:
        raise api_error(404, "category_not_found", "Category not found.")
    before = {k: getattr(category, k) for k in body.model_dump(exclude_unset=True)}
    for key, value in body.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(category, key, value)
    admin_audit(db, admin, request, "category.update", "service_category", category.id, before, body.model_dump(exclude_unset=True))
    db.commit()
    return {"id": category.id}


@router.get("/coupons")
def list_coupons(db: Session = Depends(get_db), admin: AdminUser = Depends(get_admin)):
    rows = db.scalars(select(Coupon).order_by(Coupon.created_at.desc())).all()
    return [
        {
            "id": c.id,
            "code": c.code,
            "description": c.description,
            "discount_type": c.discount_type,
            "value": c.value,
            "max_discount_paise": c.max_discount_paise,
            "min_fare_paise": c.min_fare_paise,
            "max_uses": c.max_uses,
            "per_user_limit": c.per_user_limit,
            "used_count": c.used_count,
            "categories": c.categories,
            "valid_from": c.valid_from,
            "valid_until": c.valid_until,
            "is_active": c.is_active,
        }
        for c in rows
    ]


@router.post("/coupons", status_code=201)
def create_coupon(
    body: CouponCreate,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    if db.scalar(select(Coupon).where(func.upper(Coupon.code) == body.code.upper())):
        raise api_error(409, "coupon_exists", "That coupon code already exists.")
    coupon = Coupon(**body.model_dump(), code=body.code.upper(), valid_from=utcnow())
    db.add(coupon)
    db.flush()
    admin_audit(db, admin, request, "coupon.create", "coupon", coupon.id, None, body.model_dump(mode="json"))
    db.commit()
    return {"id": coupon.id, "code": coupon.code}


@router.patch("/coupons/{coupon_id}")
def update_coupon(
    coupon_id: str,
    body: CouponUpdate,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    coupon = db.get(Coupon, coupon_id)
    if not coupon:
        raise api_error(404, "coupon_not_found", "Coupon not found.")
    before = {k: getattr(coupon, k) for k in body.model_dump(exclude_unset=True)}
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(coupon, key, value)
    admin_audit(db, admin, request, "coupon.update", "coupon", coupon.id, before, body.model_dump(exclude_unset=True, mode="json"))
    db.commit()
    return {"id": coupon.id}


@router.get("/power-pass")
def get_power_pass(db: Session = Depends(get_db), admin: AdminUser = Depends(get_admin)):
    plans = db.scalars(select(PowerPassPlan)).all()
    return [
        {
            "id": p.id,
            "code": p.code,
            "name": p.name,
            "description": p.description,
            "price_paise": p.price_paise,
            "price_display": money(p.price_paise),
            "discount_pct": p.discount_pct,
            "max_discount_paise": p.max_discount_paise,
            "ride_limit": p.ride_limit,
            "validity_days": p.validity_days,
            "is_active": p.is_active,
        }
        for p in plans
    ]


@router.patch("/power-pass/{plan_id}")
def update_power_pass(
    plan_id: str,
    body: PowerPassUpdate,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    plan = db.get(PowerPassPlan, plan_id)
    if not plan:
        raise api_error(404, "plan_not_found", "Power Pass plan not found.")
    before = {k: getattr(plan, k) for k in body.model_dump(exclude_unset=True)}
    for key, value in body.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(plan, key, value)
    admin_audit(db, admin, request, "power_pass.update", "power_pass_plan", plan.id, before, body.model_dump(exclude_unset=True))
    db.commit()
    return {"id": plan.id}


# ----------------------------- Support -----------------------------


def ticket_full(db: Session, t: SupportTicket) -> dict:
    messages = db.scalars(
        select(TicketMessage).where(TicketMessage.ticket_id == t.id).order_by(TicketMessage.created_at)
    ).all()
    user = db.get(User, t.user_id)
    return {
        "id": t.id,
        "user_id": t.user_id,
        "user_phone": masked_phone(user.phone) if user else None,
        "user_role": user.role if user else None,
        "ride_request_id": t.ride_request_id,
        "category": t.category,
        "subject": t.subject,
        "description": t.description,
        "status": t.status,
        "priority": t.priority,
        "resolution_notes": t.resolution_notes,
        "created_at": t.created_at,
        "updated_at": t.updated_at,
        "resolved_at": t.resolved_at,
        "messages": [
            {"id": m.id, "sender_type": m.sender_type, "body": m.body, "created_at": m.created_at}
            for m in messages
        ],
    }


@router.get("/tickets")
def list_tickets(
    status: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(25, ge=1, le=100),
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    stmt = select(SupportTicket)
    if status:
        stmt = stmt.where(SupportTicket.status == status)
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(
        stmt.order_by(SupportTicket.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return {"items": [ticket_full(db, t) for t in rows], "total": total, "page": page, "page_size": page_size}


@router.get("/tickets/{ticket_id}")
def ticket_detail(ticket_id: str, db: Session = Depends(get_db), admin: AdminUser = Depends(get_admin)):
    t = db.get(SupportTicket, ticket_id)
    if not t:
        raise api_error(404, "ticket_not_found", "Ticket not found.")
    return ticket_full(db, t)


@router.post("/tickets/{ticket_id}/reply")
async def admin_reply(
    ticket_id: str,
    body: TicketReplyBody,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    t = db.get(SupportTicket, ticket_id)
    if not t:
        raise api_error(404, "ticket_not_found", "Ticket not found.")
    db.add(TicketMessage(ticket_id=t.id, sender_type="admin", sender_id=admin.id, body=body.body))
    t.status = "pending"
    t.updated_at = utcnow()
    admin_audit(db, admin, request, "ticket.reply", "support_ticket", t.id)
    db.commit()
    await manager.send_to_user(t.user_id, envelope("support.ticket_updated", t.id, {"ticket_id": t.id, "status": t.status}))
    return ticket_full(db, t)


@router.post("/tickets/{ticket_id}/resolve")
async def resolve_ticket(
    ticket_id: str,
    body: TicketResolve,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    t = db.get(SupportTicket, ticket_id)
    if not t:
        raise api_error(404, "ticket_not_found", "Ticket not found.")
    t.status = body.status
    t.resolution_notes = body.resolution_notes
    t.resolved_at = utcnow()
    t.assigned_admin_id = admin.id
    admin_audit(db, admin, request, "ticket.resolve", "support_ticket", t.id, None, body.model_dump())
    db.commit()
    await manager.send_to_user(t.user_id, envelope("support.ticket_updated", t.id, {"ticket_id": t.id, "status": t.status}))
    return ticket_full(db, t)


# ----------------------------- Payments and payouts -----------------------------


@router.get("/payments")
def payments(
    status: str | None = None,
    purpose: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(25, ge=1, le=100),
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    stmt = select(PaymentTransaction)
    if status:
        stmt = stmt.where(PaymentTransaction.status == status)
    if purpose:
        stmt = stmt.where(PaymentTransaction.purpose == purpose)
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(
        stmt.order_by(PaymentTransaction.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return {
        "items": [
            {
                "id": p.id,
                "user_id": p.user_id,
                "ride_request_id": p.ride_request_id,
                "purpose": p.purpose,
                "amount_paise": p.amount_paise,
                "amount_display": money(p.amount_paise),
                "method": p.method,
                "provider": p.provider,
                "status": p.status,
                "sandbox": p.provider == "sandbox",
                "signature_verified": p.signature_verified,
                "created_at": p.created_at,
                "captured_at": p.captured_at,
            }
            for p in rows
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/refunds")
def refunds(
    status: str | None = None,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    stmt = select(Refund)
    if status:
        stmt = stmt.where(Refund.status == status)
    rows = db.scalars(stmt.order_by(Refund.created_at.desc()).limit(100)).all()
    return [
        {
            "id": r.id,
            "payment_id": r.payment_id,
            "user_id": r.user_id,
            "ride_request_id": r.ride_request_id,
            "amount_paise": r.amount_paise,
            "amount_display": money(r.amount_paise),
            "reason": r.reason,
            "status": r.status,
            "admin_note": r.admin_note,
            "provider_refund_id": r.provider_refund_id,
            "created_at": r.created_at,
            "processed_at": r.processed_at,
        }
        for r in rows
    ]


@router.post("/refunds/{refund_id}/decision")
async def refund_decision(
    refund_id: str,
    body: RefundDecision,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    refund = db.get(Refund, refund_id)
    if not refund:
        raise api_error(404, "refund_not_found", "Refund not found.")
    before = {"status": refund.status}
    decided = decide_refund(db, refund, body.decision, body.note, admin.id)
    admin_audit(db, admin, request, f"refund.{body.decision}", "refund", refund.id, before, {"status": decided.status, "note": body.note})
    db.commit()
    await manager.send_to_user(refund.user_id, envelope("payment.updated", refund.id, {"refund_id": refund.id, "status": refund.status}))
    return {"id": refund.id, "status": refund.status, "provider_refund_id": refund.provider_refund_id}


@router.get("/payouts")
def payouts(
    status: str | None = None,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    stmt = select(PayoutRequest)
    if status:
        stmt = stmt.where(PayoutRequest.status == status)
    rows = db.scalars(stmt.order_by(PayoutRequest.requested_at.desc()).limit(100)).all()
    return [
        {
            "id": p.id,
            "captain_id": p.captain_id,
            "amount_paise": p.amount_paise,
            "amount_display": money(p.amount_paise),
            "method": p.method,
            "destination_masked": p.destination_masked,
            "status": p.status,
            "requested_at": p.requested_at,
            "processed_at": p.processed_at,
            "admin_note": p.admin_note,
            "provider_reference": p.provider_reference,
        }
        for p in rows
    ]


@router.post("/payouts/{payout_id}/decision")
async def payout_decision(
    payout_id: str,
    body: PayoutDecision,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    payout = db.get(PayoutRequest, payout_id)
    if not payout:
        raise api_error(404, "payout_not_found", "Payout not found.")
    before = {"status": payout.status}
    if body.decision == "approve":
        if payout.status != "requested":
            raise api_error(409, "payout_state", "Only requested payouts can be approved.")
        payout.status = "approved"
    elif body.decision == "complete":
        if payout.status not in {"requested", "approved", "processing"}:
            raise api_error(409, "payout_state", "This payout cannot be completed.")
        payout.status = "completed"
        payout.processed_at = utcnow()
        payout.provider_reference = body.provider_reference or f"manual_{new_opaque_token(6)}"
    else:
        if payout.status in {"completed", "rejected", "failed"}:
            raise api_error(409, "payout_state", "This payout is already final.")
        payout.status = "rejected" if body.decision == "reject" else "failed"
        payout.processed_at = utcnow()
        reverse_payout_hold(db, payout)
    payout.admin_id = admin.id
    payout.admin_note = body.note
    admin_audit(db, admin, request, f"payout.{body.decision}", "payout_request", payout.id, before, {"status": payout.status, "note": body.note})
    db.commit()
    await manager.send_to_user(payout.captain_id, envelope("payout.updated", payout.id, {"payout_id": payout.id, "status": payout.status}))
    return {"id": payout.id, "status": payout.status}


# ----------------------------- Areas, settings, audit -----------------------------


@router.get("/service-areas")
def list_areas(db: Session = Depends(get_db), admin: AdminUser = Depends(get_admin)):
    rows = db.scalars(select(ServiceArea).order_by(ServiceArea.city)).all()
    return [
        {
            "id": a.id,
            "name": a.name,
            "city": a.city,
            "center_lat": a.center_lat,
            "center_lng": a.center_lng,
            "radius_km": a.radius_km,
            "is_active": a.is_active,
        }
        for a in rows
    ]


@router.post("/service-areas", status_code=201)
def create_area(
    body: ServiceAreaCreate,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    area = ServiceArea(**body.model_dump())
    db.add(area)
    db.flush()
    admin_audit(db, admin, request, "service_area.create", "service_area", area.id, None, body.model_dump())
    db.commit()
    return {"id": area.id}


@router.patch("/service-areas/{area_id}")
def update_area(
    area_id: str,
    body: ServiceAreaUpdate,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    area = db.get(ServiceArea, area_id)
    if not area:
        raise api_error(404, "area_not_found", "Service area not found.")
    before = {k: getattr(area, k) for k in body.model_dump(exclude_unset=True)}
    for key, value in body.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(area, key, value)
    admin_audit(db, admin, request, "service_area.update", "service_area", area.id, before, body.model_dump(exclude_unset=True))
    db.commit()
    return {"id": area.id}


@router.get("/settings")
def get_settings(db: Session = Depends(get_db), admin: AdminUser = Depends(get_admin)):
    rows = db.scalars(select(AppSetting).order_by(AppSetting.key)).all()
    return [
        {"key": s.key, "value": s.value, "description": s.description, "updated_at": s.updated_at}
        for s in rows
    ]


@router.put("/settings/{key}")
def set_setting(
    key: str,
    body: SettingUpdate,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    if len(key) > 80:
        raise api_error(400, "key_invalid", "Setting key is too long.")
    setting = db.get(AppSetting, key)
    before = setting.value if setting else None
    if setting:
        setting.value = body.value
        setting.description = body.description or setting.description
        setting.updated_by = admin.id
    else:
        setting = AppSetting(key=key, value=body.value, description=body.description, updated_by=admin.id)
        db.add(setting)
    admin_audit(db, admin, request, "setting.update", "app_setting", key, before, body.value)
    db.commit()
    return {"key": key, "value": setting.value}


@router.get("/audit-logs")
def audit_logs(
    entity_type: str | None = None,
    action: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    stmt = select(AuditLog)
    if entity_type:
        stmt = stmt.where(AuditLog.entity_type == entity_type)
    if action:
        stmt = stmt.where(AuditLog.action == action)
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(
        stmt.order_by(AuditLog.id.desc()).offset((page - 1) * page_size).limit(page_size)
    ).all()
    return {
        "items": [
            {
                "id": a.id,
                "actor_type": a.actor_type,
                "actor_id": a.actor_id,
                "action": a.action,
                "entity_type": a.entity_type,
                "entity_id": a.entity_id,
                "before": a.before,
                "after": a.after,
                "ip_address": a.ip_address,
                "request_id": a.request_id,
                "created_at": a.created_at,
            }
            for a in rows
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/safety-incidents")
def safety_incidents(
    status: str | None = None,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    stmt = select(SafetyIncident)
    if status:
        stmt = stmt.where(SafetyIncident.status == status)
    rows = db.scalars(stmt.order_by(SafetyIncident.created_at.desc()).limit(100)).all()
    return [
        {
            "id": i.id,
            "user_id": i.user_id,
            "ride_request_id": i.ride_request_id,
            "status": i.status,
            "lat": i.lat,
            "lng": i.lng,
            "contacts_notified": i.contacts_notified,
            "emergency_services_contacted": i.emergency_services_contacted,
            "note": i.note,
            "resolution": i.resolution,
            "created_at": i.created_at,
            "cancelled_at": i.cancelled_at,
            "resolved_at": i.resolved_at,
        }
        for i in rows
    ]


@router.post("/safety-incidents/{incident_id}/resolve")
async def resolve_incident(
    incident_id: str,
    body: dict,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(get_admin),
):
    incident = db.get(SafetyIncident, incident_id)
    if not incident:
        raise api_error(404, "incident_not_found", "Safety incident not found.")
    resolution = str(body.get("resolution", "")).strip()
    if len(resolution) < 3:
        raise api_error(400, "resolution_required", "Add a short resolution note.")
    incident.status = "resolved"
    incident.resolution = resolution
    incident.resolved_by = admin.id
    incident.resolved_at = utcnow()
    admin_audit(db, admin, request, "safety.resolve", "safety_incident", incident.id, None, {"resolution": resolution})
    db.commit()
    await manager.send_to_user(incident.user_id, envelope("safety.updated", incident.id, {"status": "resolved"}))
    return {"id": incident.id, "status": incident.status}


@router.get("/admins")
def list_admins(
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin")),
):
    rows = db.scalars(select(AdminUser).order_by(AdminUser.created_at)).all()
    return [admin_dict(a) for a in rows]


@router.post("/admins", status_code=201)
def add_admin(
    body: AdminCreate,
    request: Request,
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin")),
):
    created = create_admin(
        db, email=body.email, name=body.name, password=body.password, role=body.role
    )
    admin_audit(db, admin, request, "admin.create", "admin_user", created.id, None, {"email": created.email, "role": created.role})
    db.commit()
    return admin_dict(created)


@router.get("/exports/rides.csv")
def export_rides(
    db: Session = Depends(get_db),
    admin: AdminUser = Depends(require_admin_role("super_admin", "admin")),
):
    rows = db.scalars(select(RideRequest).order_by(RideRequest.created_at.desc()).limit(5000)).all()
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(["ride_id", "category", "status", "pickup", "drop", "fare_inr", "passenger_id", "captain_id", "created_at"])
    for r in rows:
        writer.writerow([r.id, r.category, r.status, r.pickup_address, r.drop_address, f"{r.quoted_fare_paise/100:.2f}", r.passenger_id, r.assigned_captain_id or "", r.created_at.isoformat()])
    return Response(
        content=buffer.getvalue(),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=neev-rides.csv"},
    )
