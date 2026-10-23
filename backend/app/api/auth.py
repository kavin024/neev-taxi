from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.api.deps import api_error, get_current_user
from app.core.database import get_db
from app.core.rate_limit import rate_limit
from app.models import User
from app.schemas.auth import (
    LogoutBody,
    OtpRequestBody,
    OtpRequestOut,
    OtpVerifyBody,
    RefreshBody,
    UserMe,
)
from app.schemas.common import Message, TokenPair
from app.services.auth_service import (
    request_otp,
    revoke_all_sessions,
    revoke_refresh_token,
    rotate_refresh_token,
    serialize_user,
    verify_otp,
)

router = APIRouter(prefix="/auth", tags=["authentication"])


@router.post("/otp/request", response_model=OtpRequestOut, dependencies=[Depends(rate_limit("otp_request", 12, 600))])
def otp_request(body: OtpRequestBody, request: Request, db: Session = Depends(get_db)):
    challenge, dev_otp, delivery, ttl = request_otp(
        db, phone=body.phone, role=body.role, request_ip=request.client.host if request.client else None
    )
    return OtpRequestOut(
        challenge_id=challenge.id,
        phone=challenge.phone,
        expires_in=ttl,
        resend_after=60,
        dev_otp=dev_otp,
        delivery=delivery,
    )


@router.post(
    "/otp/verify",
    response_model=TokenPair,
    dependencies=[Depends(rate_limit("otp_verify", 20, 600))],
)
def otp_verify(body: OtpVerifyBody, request: Request, db: Session = Depends(get_db)):
    user, access, refresh, expires_in = verify_otp(
        db,
        phone=body.phone,
        code=body.code,
        role=body.role,
        device_id=body.device_id,
        user_agent=request.headers.get("user-agent"),
    )
    return TokenPair(
        access_token=access,
        refresh_token=refresh,
        expires_in=expires_in,
        user=serialize_user(user, db),
    )


@router.post("/refresh", response_model=TokenPair)
def refresh(body: RefreshBody, request: Request, db: Session = Depends(get_db)):
    user, access, refresh_token, expires_in = rotate_refresh_token(
        db, body.refresh_token, user_agent=request.headers.get("user-agent")
    )
    return TokenPair(
        access_token=access,
        refresh_token=refresh_token,
        expires_in=expires_in,
        user=serialize_user(user, db),
    )


@router.post("/logout", response_model=Message)
def logout(
    body: LogoutBody,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    revoke_refresh_token(db, body.refresh_token)
    return Message(message="Signed out.")


@router.post("/logout-all", response_model=Message)
def logout_all(
    db: Session = Depends(get_db), user: User = Depends(get_current_user)
):
    revoke_all_sessions(db, user)
    return Message(message="All sessions revoked.")


@router.get("/me", response_model=UserMe)
def me(user: User = Depends(get_current_user)):
    return serialize_user(user)
