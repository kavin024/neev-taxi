#!/usr/bin/env python3
"""Run the full Neev backend with an embedded PostgreSQL for local development.

Usage:
    .venv/bin/python scripts/dev_backend.py [--host 127.0.0.1] [--port 8000] [--reload]

What it does:
  1. starts/attaches an embedded PostgreSQL (pgserver) at NEEV_PG_DATA
  2. creates the `neev` database if missing
  3. runs `alembic upgrade head`
  4. seeds clearly-labelled demo data (idempotent)
  5. starts uvicorn

This is a development convenience only. Production uses DATABASE_URL pointing at
a managed PostgreSQL/PostGIS instance and runs migrations as a deploy step.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
PGDATA = os.environ.get("NEEV_PG_DATA", "/tmp/opencode/pgdata")
DB_NAME = os.environ.get("NEEV_PG_DB", "neev")


def ensure_database() -> str:
    import pgserver

    Path(PGDATA).mkdir(parents=True, exist_ok=True)
    server = pgserver.get_server(PGDATA, cleanup_mode=None)
    # Keep a module-level reference so the embedded server is not finalized.
    globals()["_server"] = server
    try:
        server.psql(f"CREATE DATABASE {DB_NAME};")
        print(f"[dev] created database {DB_NAME}")
    except Exception:
        print(f"[dev] database {DB_NAME} already present")
    return f"postgresql+psycopg://postgres@/{DB_NAME}?host={PGDATA}"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--reload", action="store_true")
    parser.add_argument("--no-seed", action="store_true")
    args = parser.parse_args()

    url = ensure_database()
    os.environ["NEEV_DATABASE_URL"] = url
    os.environ.setdefault("NEEV_SECRET_KEY", "dev-only-secret-key-change-me-0123456789abcdef")

    env = {**os.environ, "NEEV_DATABASE_URL": url}
    print("[dev] migrating…")
    subprocess.run([str(ROOT / ".venv/bin/alembic"), "upgrade", "head"], cwd=BACKEND, env=env, check=True)

    if not args.no_seed:
        print("[dev] seeding demo data…")
        subprocess.run([sys.executable, str(ROOT / "scripts/seed_demo.py")], cwd=ROOT, env=env, check=True)

    print(f"[dev] API:      http://{args.host}:{args.port}")
    print(f"[dev] docs:     http://{args.host}:{args.port}/docs")
    print(f"[dev] health:   http://{args.host}:{args.port}/health")
    print(f"[dev] database: {url}")

    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=args.host,
        port=args.port,
        reload=args.reload,
        app_dir=str(BACKEND),
        log_level="info",
    )


if __name__ == "__main__":
    main()
