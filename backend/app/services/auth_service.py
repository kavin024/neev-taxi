from __future__ import annotations

from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import api_error
from app.core.config import settings
from app.core.database import utcnow
from app.core.security import (
    create_access_token,
    generate_otp,
    hash_otp,
    hash_password,
    new_opaque_token,
    sha256,
    verify_otp_hash,
    verify_password,
)
from app.integrations.sms import send_sms
from app.models import (
    AdminUser,
    OtpChallenge,
    PassengerProfile,
    RefreshToken,
    User,
)


def serialize_user(user: User, db: Session | None = None) -> dict:
    data = {
        "id": user.id,
        "phone": user.phone,
        "role": user.role,
        "status": user.status,
        "is_demo": user.is_demo,
        "phone_verified": user.phone_verified,
        "created_at": user.created_at,
    }
    if user.role == "passenger" and user.passenger_profile:
        p = user.passenger_profile
        data["name"] = p.name
        data["photo_url"] = p.photo_url
        data["passenger"] = {
            "name": p.name,
            "email": p.email,
            "photo_url": p.photo_url,
            "home_area": p.home_area,
            "total_rides": p.total_rides,
            "rating": round(p.rating_sum / p.rating_count, 2) if p.rating_count else None,
        }
    if user.role == "captain" and user.captain_profile:
        c = user.captain_profile
        data["name"] = c.name
        data["photo_url"] = c.photo_url
        data["captain"] = {
            "name": c.name,
            "verification_status": c.verification_status,
            "rejection_reason": c.rejection_reason,
            "is_online": c.is_online,
            "total_trips": c.total_trips,
            "rating": c.rating,
            "service_area_id": c.service_area_id,
        }
    return data


def issue_tokens(
    db: Session,
    user: User,
    *,
    device_id: str | None = None,
    user_agent: str | None = None,
) -> tuple[str, str, int]:
    access, expires = create_access_token(user.id, user.role, token_version=user.token_version)
    raw_refresh = new_opaque_token()
    refresh = RefreshToken(
        user_id=user.id,
        token_hash=sha256(raw_refresh),
        family_id=new_opaque_token(18),
        device_id=device_id,
        user_agent=(user_agent or "")[:300] or None,
        expires_at=utcnow() + timedelta(days=settings.refresh_token_days),
    )
    db.add(refresh)
    db.commit()
    return access, raw_refresh, int((expires - utcnow()).total_seconds())


def request_otp(
    db: Session, *, phone: str, role: str, request_ip: str | None
) -> tuple[OtpChallenge, str | None, str, int]:
    now = utcnow()
    existing = db.scalar(select(User).where(User.phone == phone))
    if existing and existing.status != "active":
        raise api_error(403, "account_inactive", f"Account is {existing.status}.")
    if existing and existing.role != role:
        raise api_error(
            409,
            "role_mismatch",
            "This number is registered for the other Neev app.",
            {"registered_role": existing.role},
        )

    latest = db.scalar(
        select(OtpChallenge)
        .where(OtpChallenge.phone == phone, OtpChallenge.purpose.in_(["login", "signup"]))
        .order_by(OtpChallenge.created_at.desc())
    )
    if latest and latest.created_at + timedelta(seconds=settings.otp_resend_cooldown_seconds) > now:
        wait = int(
            (
                latest.created_at
                + timedelta(seconds=settings.otp_resend_cooldown_seconds)
                - now
            ).total_seconds()
        )
        raise api_error(
            429,
            "otp_cooldown",
            f"Please wait {max(wait, 1)} seconds before requesting another code.",
            {"retry_after": max(wait, 1)},
        )
    hourly = db.scalar(
        select(func.count(OtpChallenge.id)).where(
            OtpChallenge.phone == phone,
            OtpChallenge.created_at > now - timedelta(hours=1),
        )
    ) or 0
    if hourly >= settings.otp_requests_per_hour:
        raise api_error(
            429,
            "otp_rate_limited",
            "Too many verification requests. Try again later.",
            {"retry_after": 3600},
        )

    # Only the newest challenge can be used.
    db.execute(
        select(OtpChallenge)
        .where(
            OtpChallenge.phone == phone,
            OtpChallenge.consumed_at.is_(None),
        )
        .with_for_update()
    )
    for old in db.scalars(
        select(OtpChallenge).where(
            OtpChallenge.phone == phone, OtpChallenge.consumed_at.is_(None)
        )
    ).all():
        old.consumed_at = now

    challenge = OtpChallenge(
        phone=phone,
        purpose="login" if existing else "signup",
        code_hash="pending",
        max_attempts=settings.otp_max_attempts,
        expires_at=now + timedelta(seconds=settings.otp_ttl_seconds),
        resend_available_at=now + timedelta(seconds=settings.otp_resend_cooldown_seconds),
        request_ip=request_ip,
    )
    db.add(challenge)
    db.flush()
    code = generate_otp()
    challenge.code_hash = hash_otp(challenge.id, code)
    db.commit()

    delivery, _ = send_sms(
        db,
        recipient=phone,
        template="login_otp",
        body=f"Your Neev verification code is {code}. It expires in {settings.otp_ttl_seconds // 60} minutes. Never share this code.",
    )
    dev_code = code if (settings.dev_otp_enabled and settings.dev_otp_return_code) else None
    return challenge, dev_code, delivery, settings.otp_ttl_seconds


def verify_otp(
    db: Session,
    *,
    phone: str,
    code: str,
    role: str,
    device_id: str | None,
    user_agent: str | None,
) -> tuple[User, str, str, int]:
    now = utcnow()
    challenge = db.scalar(
        select(OtpChallenge)
        .where(
            OtpChallenge.phone == phone,
            OtpChallenge.consumed_at.is_(None),
        )
        .order_by(OtpChallenge.created_at.desc())
        .with_for_update()
    )
    if not challenge:
        raise api_error(401, "otp_not_found", "Request a new verification code.")
    if challenge.expires_at < now:
        challenge.consumed_at = now
        db.commit()
        raise api_error(401, "otp_expired", "That code has expired. Request a new one.")
    if challenge.attempts >= challenge.max_attempts:
        raise api_error(429, "otp_attempts", "Too many incorrect attempts. Request a new code.")
    if not verify_otp_hash(challenge.id, code, challenge.code_hash):
        challenge.attempts += 1
        db.commit()
        remaining = max(challenge.max_attempts - challenge.attempts, 0)
        raise api_error(
            401,
            "otp_invalid",
            "That code is incorrect.",
            {"attempts_remaining": remaining},
        )

    challenge.consumed_at = now
    user = db.scalar(select(User).where(User.phone == phone))
    if user:
        if user.role != role:
            db.commit()
            raise api_error(409, "role_mismatch", "This number belongs to the other Neev app.")
        if user.status != "active":
            db.commit()
            raise api_error(403, "account_inactive", f"Account is {user.status}.")
    else:
        user = User(phone=phone, role=role, phone_verified=True, is_demo=False)
        db.add(user)
        db.flush()
        if role == "passenger":
            db.add(PassengerProfile(user_id=user.id, name="Neev rider"))
    user.phone_verified = True
    user.last_login_at = now
    db.commit()
    db.refresh(user)

    access, refresh, expires_in = issue_tokens(
        db, user, device_id=device_id, user_agent=user_agent
    )
    return user, access, refresh, expires_in


def rotate_refresh_token(
    db: Session, raw_token: str, *, user_agent: str | None = None
) -> tuple[User, str, str, int]:
    token_hash = sha256(raw_token)
    token = db.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash).with_for_update()
    )
    if not token:
        raise api_error(401, "refresh_invalid", "Session not found. Sign in again.")
    if token.revoked_at is not None:
        # Reuse of a rotated token: revoke the whole family.
        db.query(RefreshToken).filter(
            RefreshToken.family_id == token.family_id, RefreshToken.revoked_at.is_(None)
        ).update({"revoked_at": utcnow()})
        db.commit()
        raise api_error(401, "refresh_reused", "Session was already used. Sign in again.")
    if token.expires_at < utcnow():
        raise api_error(401, "refresh_expired", "Session expired. Sign in again.")
    user = db.get(User, token.user_id)
    if not user or user.status != "active":
        raise api_error(401, "account_inactive", "Account is unavailable.")

    access, expires = create_access_token(user.id, user.role, token_version=user.token_version)
    raw_new = new_opaque_token()
    new_token = RefreshToken(
        user_id=user.id,
        token_hash=sha256(raw_new),
        family_id=token.family_id,
        device_id=token.device_id,
        user_agent=(user_agent or token.user_agent or "")[:300] or None,
        expires_at=utcnow() + timedelta(days=settings.refresh_token_days),
    )
    db.add(new_token)
    db.flush()
    token.revoked_at = utcnow()
    token.replaced_by_id = new_token.id
    db.commit()
    return user, access, raw_new, int((expires - utcnow()).total_seconds())


def revoke_refresh_token(db: Session, raw_token: str | None) -> None:
    if not raw_token:
        return
    token = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == sha256(raw_token)))
    if token and not token.revoked_at:
        token.revoked_at = utcnow()
        db.commit()


def revoke_all_sessions(db: Session, user: User) -> None:
    user.token_version += 1
    db.query(RefreshToken).filter(
        RefreshToken.user_id == user.id, RefreshToken.revoked_at.is_(None)
    ).update({"revoked_at": utcnow()})
    db.commit()


def admin_login(db: Session, email: str, password: str) -> tuple[AdminUser, str, int]:
    admin = db.scalar(select(AdminUser).where(func.lower(AdminUser.email) == email.strip().lower()))
    if not admin or not verify_password(password, admin.password_hash):
        raise api_error(401, "admin_login_failed", "Email or password is incorrect.")
    if not admin.is_active:
        raise api_error(403, "admin_inactive", "This admin account is disabled.")
    admin.last_login_at = utcnow()
    db.commit()
    token, expires = create_access_token(
        admin.id, admin.role, admin=True, token_version=admin.token_version
    )
    return admin, token, int((expires - utcnow()).total_seconds())


def create_admin(
    db: Session, *, email: str, name: str, password: str, role: str
) -> AdminUser:
    if db.scalar(select(AdminUser).where(func.lower(AdminUser.email) == email.lower())):
        raise api_error(409, "admin_exists", "An admin with that email already exists.")
    admin = AdminUser(
        email=email.lower().strip(),
        name=name,
        password_hash=hash_password(password),
        role=role,
    )
    db.add(admin)
    db.commit()
    return admin
