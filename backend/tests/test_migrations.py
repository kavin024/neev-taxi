from __future__ import annotations

import os
import subprocess
import sys
import uuid
from pathlib import Path

import psycopg

BACKEND = Path(__file__).resolve().parents[1]
PGDATA = os.environ.get("NEEV_TEST_PG_DATA", "/tmp/opencode/pgdata-test")


def test_alembic_migrations_build_the_schema_from_scratch():
    dbname = f"neev_mig_{uuid.uuid4().hex[:10]}"
    with psycopg.connect(
        host=PGDATA, user="postgres", dbname="postgres", autocommit=True
    ) as admin:
        admin.execute(f'CREATE DATABASE "{dbname}"')

    url = f"postgresql+psycopg://postgres@/{dbname}?host={PGDATA}"
    env = {**os.environ, "NEEV_DATABASE_URL": url, "NEEV_APP_ENV": "test"}
    try:
        result = subprocess.run(
            [sys.executable, "-m", "alembic", "upgrade", "head"],
            cwd=BACKEND,
            env=env,
            capture_output=True,
            text=True,
            timeout=120,
        )
        assert result.returncode == 0, result.stderr + result.stdout

        with psycopg.connect(host=PGDATA, user="postgres", dbname=dbname) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT count(*) FROM information_schema.tables "
                    "WHERE table_schema = 'public'"
                )
                table_count = cur.fetchone()[0]
                assert table_count >= 38
                cur.execute("SELECT version_num FROM alembic_version")
                assert cur.fetchone()[0]

                # Spot-check the constraints that carry correctness guarantees.
                cur.execute(
                    "SELECT constraint_name FROM information_schema.table_constraints "
                    "WHERE table_name = 'ride_requests' AND constraint_type = 'UNIQUE'"
                )
                names = {row[0] for row in cur.fetchall()}
                assert any("idempotency" in name for name in names)
    finally:
        with psycopg.connect(
            host=PGDATA, user="postgres", dbname="postgres", autocommit=True
        ) as admin:
            admin.execute(f'DROP DATABASE IF EXISTS "{dbname}" WITH (FORCE)')
