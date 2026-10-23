#!/usr/bin/env python3
"""Start the embedded development PostgreSQL without the API.

Prints the DATABASE_URL to export, then stays alive until interrupted.
"""
from __future__ import annotations

import os
import time
from pathlib import Path

PGDATA = os.environ.get("NEEV_PG_DATA", "/tmp/opencode/pgdata")
DB_NAME = os.environ.get("NEEV_PG_DB", "neev")


def main() -> None:
    import pgserver

    Path(PGDATA).mkdir(parents=True, exist_ok=True)
    server = pgserver.get_server(PGDATA, cleanup_mode=None)
    try:
        server.psql(f"CREATE DATABASE {DB_NAME};")
    except Exception:
        pass
    print(f"export NEEV_DATABASE_URL='postgresql+psycopg://postgres@/{DB_NAME}?host={PGDATA}'")
    print("PostgreSQL is running. Press Ctrl+C to stop this wrapper (data is kept).")
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        print("\n[dev_db] stopped")


if __name__ == "__main__":
    main()
