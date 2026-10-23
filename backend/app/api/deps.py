from __future__ import annotations

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import decode_token
from app.models import AdminUser, CaptainProfile, PassengerProfile, User

bearer = HTTPBearer(auto_error=False)
admin_bearer = HTTPBearer(auto_error=False)


def api_error(status_code: int, code: str, message: str, details=None) -> HTTPException:
    return HTTPException(
        status_code=status_code,
        detail={"code": code, "message": message, "details": details},
    )


def client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    if not credentials:
        raise api_error(status.HTTP_401_UNAUTHORIZED, "not_authenticated", "Sign in to continue.")
    try:
        payload = decode_token(credentials.credentials)
    except Exception:
        raise api_error(status.HTTP_401_UNAUTHORIZED, "invalid_token", "Your session is invalid or has expired.")
    if payload.get("typ") != "access":
        raise api_error(status.HTTP_401_UNAUTHORIZED, "invalid_token", "Invalid token type.")
    user = db.get(User, payload.get("sub"))
    if not user:
        raise api_error(status.HTTP_401_UNAUTHORIZED, "invalid_token", "Account not found.")
    if user.status != "active":
        raise api_error(status.HTTP_403_FORBIDDEN, "account_inactive", f"Account is {user.status}.")
    if int(payload.get("ver", 0)) != user.token_version:
        raise api_error(status.HTTP_401_UNAUTHORIZED, "session_revoked", "Session was revoked. Sign in again.")
    return user


def require_role(*roles: str):
    def _dependency(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise api_error(status.HTTP_403_FORBIDDEN, "forbidden", "This action is not available for your role.")
        return user

    return _dependency


def get_passenger(user: User = Depends(require_role("passenger"))) -> User:
    return user


def get_captain(
    user: User = Depends(require_role("captain")), db: Session = Depends(get_db)
) -> User:
    profile = db.get(CaptainProfile, user.id)
    if not profile:
        raise api_error(status.HTTP_409_CONFLICT, "onboarding_required", "Complete captain onboarding first.")
    return user


def get_approved_captain(
    user: User = Depends(get_captain), db: Session = Depends(get_db)
) -> User:
    profile = db.get(CaptainProfile, user.id)
    if profile.verification_status != "approved":
        raise api_error(
            status.HTTP_403_FORBIDDEN,
            "captain_not_approved",
            "Your captain account is not approved yet.",
            {"verification_status": profile.verification_status},
        )
    return user


def ensure_profile(db: Session, user: User) -> None:
    if user.role == "passenger" and not db.get(PassengerProfile, user.id):
        db.add(PassengerProfile(user_id=user.id))
        db.commit()


def get_admin(
    credentials: HTTPAuthorizationCredentials | None = Depends(admin_bearer),
    db: Session = Depends(get_db),
) -> AdminUser:
    if not credentials:
        raise api_error(status.HTTP_401_UNAUTHORIZED, "not_authenticated", "Admin sign-in required.")
    try:
        payload = decode_token(credentials.credentials, admin=True)
    except Exception:
        raise api_error(status.HTTP_401_UNAUTHORIZED, "invalid_token", "Admin session is invalid or expired.")
    admin = db.get(AdminUser, payload.get("sub"))
    if not admin or not admin.is_active:
        raise api_error(status.HTTP_401_UNAUTHORIZED, "invalid_token", "Admin account unavailable.")
    if int(payload.get("ver", 0)) != admin.token_version:
        raise api_error(status.HTTP_401_UNAUTHORIZED, "session_revoked", "Admin session was revoked.")
    return admin


def require_admin_role(*roles: str):
    def _dependency(admin: AdminUser = Depends(get_admin)) -> AdminUser:
        if admin.role not in roles:
            raise api_error(status.HTTP_403_FORBIDDEN, "forbidden", "Your admin role cannot perform this action.")
        return admin

    return _dependency
