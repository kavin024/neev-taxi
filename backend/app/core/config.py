from __future__ import annotations

import secrets
from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Load .env files relative to the backend package, not the process CWD, so the API
# behaves the same whether it is launched from the repo root or backend/.
BACKEND_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    """Runtime configuration. All secrets come from the environment."""

    model_config = SettingsConfigDict(
        env_file=(str(BACKEND_DIR / ".env"), str(BACKEND_DIR / ".env.local")),
        env_prefix="NEEV_",
        extra="ignore",
    )

    app_name: str = "Neev Mobility API"
    app_env: Literal["development", "test", "staging", "production"] = "development"
    debug: bool = False
    api_prefix: str = "/api/v1"
    public_base_url: str = "http://localhost:8000"
    cors_origins: str = "http://localhost:5173,http://localhost:8080,http://localhost:8081"

    database_url: str = "postgresql+psycopg://postgres@/neev?host=/tmp/neev-pg"
    db_echo: bool = False
    db_pool_size: int = 5
    db_max_overflow: int = 5

    secret_key: str = Field(default_factory=lambda: secrets.token_urlsafe(48))
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 15
    refresh_token_days: int = 30
    admin_access_token_minutes: int = 30

    otp_ttl_seconds: int = 120
    otp_length: int = 6
    otp_max_attempts: int = 5
    otp_resend_cooldown_seconds: int = 45
    otp_requests_per_hour: int = 8

    # Development-only adapters. Refuse to start in production if enabled.
    dev_otp_enabled: bool = False
    dev_otp_fixed_code: str | None = None
    dev_otp_return_code: bool = False
    dev_auto_approve_captains: bool = False
    dev_allow_gps_simulation: bool = False

    dispatch_radius_km: float = 5.0
    search_timeout_seconds: int = 90
    offer_timeout_seconds: int = 45
    captain_stale_location_seconds: int = 180
    max_offers_per_request: int = 8
    pin_ttl_minutes: int = 30
    pin_max_attempts: int = 5
    location_max_age_seconds: int = 180
    route_deviation_threshold_m: int = 500

    map_provider: Literal["demo", "osm"] = "demo"
    map_tile_url: str = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
    osm_nominatim_url: str = "https://nominatim.openstreetmap.org"
    osm_osrm_url: str = "https://router.project-osrm.org"
    geocoder_user_agent: str = "NeevDev/0.1 (local development only)"

    payment_provider: Literal["sandbox", "razorpay"] = "sandbox"
    sandbox_payment_secret: str = Field(default_factory=lambda: secrets.token_urlsafe(32))
    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""
    razorpay_webhook_secret: str = ""

    sms_provider: Literal["outbox", "twilio"] = "outbox"
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_from_number: str = ""

    upload_dir: str = "var/uploads"
    max_upload_bytes: int = 10 * 1024 * 1024
    document_url_ttl_seconds: int = 300
    share_link_ttl_minutes: int = 240
    sos_cooldown_minutes: int = 30

    enable_redis: bool = False
    redis_url: str = "redis://localhost:6379/0"
    run_background_jobs: bool = True

    @field_validator("cors_origins")
    @classmethod
    def _strip_origins(cls, value: str) -> str:
        return ",".join(part.strip() for part in value.split(",") if part.strip())

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin for origin in self.cors_origins.split(",") if origin]

    @property
    def is_dev(self) -> bool:
        return self.app_env in {"development", "test"}

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    def assert_production_safe(self) -> None:
        """Fail closed rather than accidentally shipping development adapters."""
        if not self.is_production:
            return
        problems: list[str] = []
        if self.dev_otp_enabled or self.dev_otp_fixed_code:
            problems.append("development OTP adapter is enabled")
        if self.dev_otp_return_code:
            problems.append("OTP codes are returned to clients")
        if self.dev_allow_gps_simulation:
            problems.append("GPS simulation is enabled")
        if self.payment_provider == "sandbox":
            problems.append("sandbox payment provider is enabled")
        if self.sms_provider == "outbox":
            problems.append("outbox SMS provider is enabled")
        if self.secret_key and len(self.secret_key) < 32:
            problems.append("secret_key is shorter than 32 characters")
        if problems:
            raise RuntimeError(
                "Unsafe production configuration: " + "; ".join(problems)
            )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
