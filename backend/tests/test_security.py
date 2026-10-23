from __future__ import annotations

import pytest

from app.core.config import Settings
from app.core.security import (
    create_access_token,
    decode_token,
    encrypt_trip_pin,
    decrypt_trip_pin,
    hash_otp,
    hash_trip_pin,
    verify_trip_pin,
)
from app.services.security_utils import hash_share_token, masked_phone


def test_production_configuration_fails_closed():
    unsafe = Settings(
        app_env="production",
        dev_otp_enabled=True,
        dev_otp_return_code=True,
        payment_provider="sandbox",
        sms_provider="outbox",
        secret_key="short",
    )
    with pytest.raises(RuntimeError) as exc:
        unsafe.assert_production_safe()
    message = str(exc.value)
    assert "development OTP" in message
    assert "sandbox payment" in message
    assert "outbox SMS" in message


def test_admin_and_api_tokens_are_not_interchangeable():
    api_token, _ = create_access_token("user-1", "passenger")
    admin_token, _ = create_access_token("admin-1", "super_admin", admin=True)

    with pytest.raises(Exception):
        decode_token(admin_token, admin=False)
    with pytest.raises(Exception):
        decode_token(api_token, admin=True)
    assert decode_token(api_token)["role"] == "passenger"
    assert decode_token(admin_token, admin=True)["role"] == "super_admin"


def test_share_tokens_are_hashed_with_a_salt():
    token = "share-token-that-must-not-be-stored"
    digest = hash_share_token(token)
    assert digest != token
    assert len(digest) == 64
    assert hash_share_token(token) == digest
    assert hash_share_token(token + "x") != digest


def test_trip_pin_hash_and_encryption_are_trip_bound():
    pin = "4821"
    assert verify_trip_pin("trip-a", pin, hash_trip_pin("trip-a", pin))
    assert not verify_trip_pin("trip-b", pin, hash_trip_pin("trip-a", pin))

    encrypted = encrypt_trip_pin("trip-a", pin)
    assert pin not in encrypted
    assert decrypt_trip_pin("trip-a", encrypted) == pin
    assert decrypt_trip_pin("trip-b", encrypted) is None


def test_otp_hash_is_challenge_bound():
    first = hash_otp("challenge-a", "123456")
    second = hash_otp("challenge-b", "123456")
    assert first != second
    assert "123456" not in first


def test_masked_phone_hides_middle_digits():
    masked = masked_phone("+919000000011")
    assert masked.startswith("+91")
    assert masked.endswith("11")
    assert "000000" not in masked
