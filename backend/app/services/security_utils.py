from __future__ import annotations

import hashlib

from app.core.security import hmac_hex


def hash_share_token(raw_token: str) -> str:
    # Salted HMAC so a leaked database cannot be used to guess share links.
    return hmac_hex("neev-trip-share", raw_token)


def masked_phone(phone: str) -> str:
    if len(phone) < 6:
        return "***"
    return phone[:3] + "****" + phone[-2:]
