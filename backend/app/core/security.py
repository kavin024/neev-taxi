from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError
from cryptography.fernet import Fernet, InvalidToken

from app.core.config import settings

password_hasher = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=2)


def hash_password(password: str) -> str:
    return password_hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return password_hasher.verify(password_hash, password)
    except (VerifyMismatchError, InvalidHashError, ValueError):
        return False


def create_access_token(
    subject: str,
    role: str,
    *,
    admin: bool = False,
    token_version: int = 0,
    extra: dict | None = None,
) -> tuple[str, datetime]:
    minutes = (
        settings.admin_access_token_minutes if admin else settings.access_token_minutes
    )
    expires = datetime.now(timezone.utc) + timedelta(minutes=minutes)
    payload = {
        "sub": subject,
        "role": role,
        "aud": "admin" if admin else "api",
        "typ": "access",
        "ver": token_version,
        "iat": int(datetime.now(timezone.utc).timestamp()),
        "exp": int(expires.timestamp()),
        "jti": secrets.token_urlsafe(12),
    }
    if extra:
        payload.update(extra)
    token = jwt.encode(payload, settings.secret_key, algorithm=settings.jwt_algorithm)
    return token, expires


def decode_token(token: str, *, admin: bool = False) -> dict:
    return jwt.decode(
        token,
        settings.secret_key,
        algorithms=[settings.jwt_algorithm],
        audience="admin" if admin else "api",
        options={"require": ["exp", "sub", "role", "typ"]},
    )


def new_opaque_token(n_bytes: int = 48) -> str:
    return secrets.token_urlsafe(n_bytes)


def sha256(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def hmac_hex(secret: str, message: str) -> str:
    return hmac.new(secret.encode(), message.encode(), hashlib.sha256).hexdigest()


def hash_otp(challenge_id: str, code: str) -> str:
    return hmac_hex(settings.secret_key, f"otp:{challenge_id}:{code}")


def verify_otp_hash(challenge_id: str, code: str, expected: str) -> bool:
    return hmac.compare_digest(hash_otp(challenge_id, code), expected)


def generate_otp() -> str:
    if settings.dev_otp_enabled and settings.dev_otp_fixed_code:
        return settings.dev_otp_fixed_code
    upper = 10 ** settings.otp_length
    return f"{secrets.randbelow(upper):0{settings.otp_length}d}"


def hash_trip_pin(trip_id: str, pin: str) -> str:
    return hmac_hex(settings.secret_key, f"pin:{trip_id}:{pin}")


def verify_trip_pin(trip_id: str, pin: str, expected: str) -> bool:
    return hmac.compare_digest(hash_trip_pin(trip_id, pin), expected)


def generate_trip_pin() -> str:
    return f"{secrets.randbelow(10000):04d}"


def _pin_cipher() -> Fernet:
    import base64

    key = base64.urlsafe_b64encode(
        hashlib.sha256(f"pin-encryption:{settings.secret_key}".encode()).digest()
    )
    return Fernet(key)


def encrypt_trip_pin(trip_id: str, pin: str) -> str:
    return _pin_cipher().encrypt(f"{trip_id}:{pin}".encode()).decode()


def decrypt_trip_pin(trip_id: str, encrypted: str) -> str | None:
    try:
        raw = _pin_cipher().decrypt(encrypted.encode()).decode()
        stored_trip, pin = raw.split(":", 1)
        return pin if stored_trip == trip_id else None
    except (InvalidToken, ValueError):
        return None
