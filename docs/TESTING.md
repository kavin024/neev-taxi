# Testing

## Running the suite

```bash
cd backend
../.venv/bin/python -m pytest -q                  # full suite
../.venv/bin/python -m pytest tests/test_dispatch.py -q
../.venv/bin/python -m pytest -q -x --lf          # stop on first failure, last failed
```

The suite runs against a real PostgreSQL instance, not SQLite. By default it starts
an embedded `pgserver` at `/tmp/opencode/pgdata-test` and creates `neev_test`; set
`NEEV_TEST_PG_DATA` / `NEEV_TEST_DB` to isolate it. `conftest.py` forces
`NEEV_APP_ENV=test`, fixed OTP `123456`, sandbox payments, demo maps and background
jobs off. Schema is created from SQLAlchemy metadata for speed; Alembic is exercised
separately.

Frontend checks:

```bash
cd apps/admin_web && npm run typecheck && npm run build

cd apps/shared_package && flutter test
cd apps/passenger_app   && flutter analyze && flutter test
cd apps/captain_app     && flutter analyze && flutter test
```

End-to-end smoke test (development backend running, freshly seeded data):

```bash
.venv/bin/python scripts/smoke_e2e.py
.venv/bin/python scripts/smoke_e2e.py --base-url http://127.0.0.1:8000
```

It logs in as a new passenger and the seeded bike captain, quotes, requests a ride,
accepts, arrives, starts with the rider PIN, pings location, completes, pays cash and
checks earnings. It fails if the seeded captain is already on an active trip.

## Layout

| File | Focus |
| --- | --- |
| `test_auth.py` | OTP request/verify, wrong-code attempts, role mismatch, refresh rotation and reuse detection, logout-all, admin login |
| `test_security.py` | Production fail-closed guard, audience separation, salted share tokens, trip-bound PIN hashing/encryption, challenge-bound OTP hashes, phone masking |
| `test_fares.py` | Itemised quotes, demo routing, coupon application and rejection, identical pickup/drop, role gating, Power Pass purchase and discount |
| `test_dispatch.py` | Exactly one winner in a concurrent accept race, offer rejection, offline/unapproved captains receive nothing |
| `test_ride_lifecycle.py` | Full request → accept → arrive → PIN start → complete flow, invalid transitions, cross-passenger isolation, idempotent requests |
| `test_payments.py` | Cash confirmation, sandbox UPI success and ledger, retry after failure, unconfigured Razorpay, insufficient wallet, honest method listing |
| `test_admin.py` | Support-role read-only limits, pricing update + audit, captain approval/suspension, auth boundaries, dashboard/export, trip events and safety visibility |
| `test_safety_support.py` | SOS never claims emergency dispatch, minimum press duration, ride-linked SOS in admin queue, ticket lifecycle, ticket privacy, notifications on trip events |
| `test_ws.py` | Token-authenticated socket, rejection of missing/bad tokens, rejection of admin tokens on the passenger socket |
| `test_migrations.py` | Alembic upgrade from an empty database builds the expected schema |

## What is intentionally covered by unit/integration tests

- Authorisation boundaries between passenger, captain, admin and support roles.
- Concurrency invariants that are hard to reproduce manually (dual accept).
- Financial invariants: quote snapshots, idempotency, ledger postings, refund state.
- Fail-closed configuration: production cannot boot with demo adapters.
- Privacy: ticket/ride isolation, masked phones, hashed share tokens.

## Not covered by automated tests (manual or future work)

- Real Razorpay/Twilio/Nominatim/OSRM integrations (only fail-closed and adapter
  boundaries are tested).
- Browser end-to-end flows for the React console and Flutter apps; add Playwright and
  Flutter integration tests before launch.
- Load, soak, and WebSocket reconnect behaviour under packet loss.
- Two-worker behaviour: the current rate limiter and socket registry are
  process-local, so tests run single-process by design.
- Accessibility and localisation audits.

## Conventions for new tests

- Prefer the existing fixtures (`client`, `passenger`, `captain`, `admin_headers`,
  `support_headers`, `db`) over hand-building sessions.
- Assert on status codes **and** error codes; the code is the stable contract.
- For money, assert exact paise and ledger balance, not formatted strings.
- For time-sensitive paths, use the configured short windows rather than sleeping;
  the expiry job can be invoked directly (`app.jobs.expiry.expire_once`).
- Any new endpoint needs at least one unauthorised, one wrong-role and one success
  test.
