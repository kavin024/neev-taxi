from __future__ import annotations

import asyncio
import logging
import time
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.middleware.base import BaseHTTPMiddleware

from app.api import admin, auth, captains, catalog, fares, notifications, payments, public
from app.api import rides, safety, support, ws
from app.api.public import root_router as public_root_router
from app.core.config import settings
from app.core.database import SessionLocal
from app.core.logging import configure_logging, request_id_ctx
from app.jobs.expiry import expiry_loop

configure_logging()
logger = logging.getLogger("neev.api")


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings.assert_production_safe()
    task = None
    if settings.run_background_jobs:
        task = asyncio.create_task(expiry_loop())
    logger.info(
        "api.started",
        extra={"environment": settings.app_env, "map_provider": settings.map_provider},
    )
    yield
    if task:
        task.cancel()


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description=(
        "Neev Mobility API — an independently built ride-booking platform. "
        "Development adapters are clearly labelled and refused in production."
    ),
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Request-ID"],
)


class RequestContextMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("X-Request-ID") or uuid.uuid4().hex
        token = request_id_ctx.set(request_id)
        request.state.request_id = request_id
        started = time.perf_counter()
        try:
            response = await call_next(request)
        finally:
            request_id_ctx.reset(token)
        response.headers["X-Request-ID"] = request_id
        logger.info(
            "http.request",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status": response.status_code,
                "latency_ms": round((time.perf_counter() - started) * 1000, 2),
                "client_ip": request.client.host if request.client else None,
            },
        )
        return response


app.add_middleware(RequestContextMiddleware)


def _error(request: Request, status: int, code: str, message: str, details=None):
    return JSONResponse(
        status_code=status,
        content={
            "error": {"code": code, "message": message, "details": details},
            "request_id": getattr(request.state, "request_id", None),
        },
        headers={"X-Request-ID": getattr(request.state, "request_id", "")},
    )


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    detail = exc.detail
    if isinstance(detail, dict):
        code = detail.get("code", "http_error")
        message = detail.get("message", "Request failed")
        details = detail.get("details")
    else:
        code = "http_error"
        message = str(detail)
        details = None
    return _error(request, exc.status_code, code, message, details)


@app.exception_handler(RequestValidationError)
async def validation_handler(request: Request, exc: RequestValidationError):
    details = []
    for item in exc.errors():
        details.append(
            {
                "field": ".".join(str(p) for p in item.get("loc", []) if p != "body"),
                "message": item.get("msg"),
                "type": item.get("type"),
            }
        )
    return _error(
        request, 422, "validation_error", "Some fields need attention.", details
    )


@app.exception_handler(Exception)
async def unhandled_handler(request: Request, exc: Exception):
    logger.exception("unhandled.error", extra={"path": request.url.path})
    return _error(
        request,
        500,
        "internal_error",
        "Something went wrong on our side. Please try again.",
    )


@app.get("/health", tags=["system"])
def health():
    db_ok = True
    try:
        with SessionLocal() as db:
            from sqlalchemy import text

            db.execute(text("SELECT 1"))
    except Exception:
        logger.exception("health.db_failed")
        db_ok = False
    return {
        "status": "ok" if db_ok else "degraded",
        "service": "neev-api",
        "version": "0.1.0",
        "environment": settings.app_env,
        "database": "ok" if db_ok else "unavailable",
        "map_provider": settings.map_provider,
        "payment_provider": settings.payment_provider,
    }


for router in (
    auth.router,
    catalog.router,
    fares.router,
    rides.router,
    captains.router,
    payments.router,
    safety.router,
    support.router,
    notifications.router,
    public.router,
    admin.router,
    ws.router,
):
    app.include_router(router, prefix=settings.api_prefix)

# Public share pages live at the root so links stay short and provider-neutral.
app.include_router(public_root_router)
