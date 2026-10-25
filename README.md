# Neev Mobility

An independently built ride-booking platform: a FastAPI backend, a React operations
console, and two Flutter clients (passenger and captain) sharing one Dart package.

Neev is original code and branding. `RAPIDO_ANALYSIS.md` is a research document
describing publicly observable behaviour of a reference product; nothing in this
repository is copied from that product, and no proprietary source, APIs, or data
were used.

## What is implemented

| Area | Capabilities |
| --- | --- |
| Identity | Phone + SMS OTP login, JWT access/refresh tokens, token revocation, persistent rider PIN, admin RBAC |
| Catalog | Service categories, service areas and geofencing, saved addresses, trusted contacts, location search/reverse geocode |
| Fares | Distance/time/base pricing per category, night multiplier, minimum fare, platform fee, coupons, Power Pass, wallet balance |
| Dispatch | Nearest eligible captain offers, vehicle/category matching, offer expiry, concurrent acceptance protection, auto-expiry job |
| Trip lifecycle | Request → assigned → arriving → arrived → in progress → completed/cancelled, trip PIN start, live location, route deviation flag |
| Payments | Sandbox gateway, cash confirmation, wallet top-up, refunds, double-entry ledger, captain payouts |
| Safety | SOS incidents with cooldown and resolution workflow, trip share links, trusted contacts, safety feature catalogue |
| Support | Tickets, threaded messages, resolution notes, notification inbox |
| Admin | Dashboard metrics, passengers, captains and documents, rides, pricing, coupons, Power Pass, payments, refunds, payouts, service areas, settings, audit log, safety, admins, CSV export |
| Realtime | Authenticated WebSocket feed plus polling fallback for ride events |

## Repository layout

```
backend/              FastAPI app, SQLAlchemy models, Alembic migrations, pytest suite
apps/admin_web/       React + TypeScript + Vite operations console
apps/passenger_app/   Flutter passenger app (web/android scaffolding)
apps/captain_app/     Flutter captain app (web/android scaffolding)
apps/shared_package/  Shared Dart API client, models, realtime, theme and widgets
scripts/              Local dev database, backend runner, idempotent demo seed
infra/                Container and reverse-proxy definitions
docs/                 Architecture, API, operations, security and testing notes
```

## Quick start (local)

Requirements: Python 3.12, Node 20+, and optionally Flutter 3.47+ (tested with
3.47.7 / Dart 3.13.5) for the mobile clients. The development backend ships with an
embedded PostgreSQL (`pgserver`), so no external database is needed.

```bash
python3.12 -m venv .venv
.venv/bin/pip install -r backend/requirements-dev.txt

# Starts embedded PostgreSQL, migrates, seeds demo data, serves on :8000
.venv/bin/python scripts/dev_backend.py
```

In a second terminal:

```bash
cd apps/admin_web
npm ci
npm run dev          # http://localhost:5173, proxies /api to :8000
```

API docs: <http://127.0.0.1:8000/docs> · health: <http://127.0.0.1:8000/health>

### Demo identities

The seed is idempotent and refuses to run when `NEEV_APP_ENV=production`.

| Role | Identity | Credential |
| --- | --- | --- |
| Super admin | `admin@neev.local` | `NeevAdmin!2026` |
| Support admin | `support@neev.local` | `NeevSupport!2026` |
| Passenger | `+919000000001` / `+919000000002` | OTP `123456` |
| Captains | `+919000000011` (bike), `+919000000012` (auto), `+919000000013` (cab) | OTP `123456` |
| Coupon | `NEEV50` | 50% off, capped at ₹50 |
| Power Pass | `POWER30` | ₹99 for 30 days, 10% off |

Demo OTP behaviour, GPS simulation, auto-approval of captain documents and the
sandbox payment provider are development adapters. `Settings.assert_production_safe`
refuses to boot with any of them enabled under `NEEV_APP_ENV=production`.

### Flutter clients

```bash
cd apps/shared_package && flutter pub get
cd ../passenger_app   && flutter pub get && flutter run -d chrome
cd ../captain_app     && flutter pub get && flutter run -d chrome
```

The clients read `API_BASE_URL` from `--dart-define`, defaulting to
`http://127.0.0.1:8000`.

## Tests

```bash
cd backend
../.venv/bin/python -m pytest -q          # 48 tests, real PostgreSQL
cd ../apps/admin_web
npm run typecheck && npm run build
cd ../passenger_app && flutter analyze && flutter test
cd ../captain_app   && flutter analyze && flutter test
```

With the development backend running, the end-to-end HTTP smoke test covers login,
quote, request, dispatch, PIN start, completion and payment:

```bash
.venv/bin/python scripts/smoke_e2e.py
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — components, data model, request flows
- [API reference](docs/API.md) — every endpoint, auth model, event stream
- [Operations](docs/OPERATIONS.md) — configuration, deployment, runbook
- [Security](docs/SECURITY.md) — threat model, controls, production checklist
- [Testing](docs/TESTING.md) — suite layout and coverage intent

## Production notes

This repository is a complete, runnable MVP, not a finished commercial service.
Before real traffic you must, at minimum: replace the sandbox payment and SMS
providers, move rate limiting and the WebSocket fan-out to shared infrastructure
(Redis), terminate TLS, configure backups and observability, complete legal and
tax review, and have the safety workflow reviewed by an operations professional.
See [docs/OPERATIONS.md](docs/OPERATIONS.md) and [docs/SECURITY.md](docs/SECURITY.md).
# neev-taxi
# neev-taxi
