# Architecture

## System shape

```
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│ Passenger app    │   │ Captain app      │   │ Operations web   │
│ Flutter          │   │ Flutter          │   │ React + Vite     │
└────────┬─────────┘   └────────┬─────────┘   └────────┬─────────┘
         │  HTTPS + WSS         │                      │ HTTPS
         └──────────────┬───────┴──────────────────────┘
                        ▼
              ┌──────────────────┐
              │ FastAPI (app)    │  REST /api/v1, /share, /health
              │                  │  WebSocket /api/v1/ws
              └───┬──────┬───────┘
                  │      │
       ┌──────────▼──┐ ┌─▼─────────────┐ ┌──────────────────┐
       │ PostgreSQL  │ │ Maps / SMS /  │ │ Local document   │
       │ SQLAlchemy  │ │ payments      │ │ storage          │
       └─────────────┘ └───────────────┘ └──────────────────┘
```

The backend is a single stateless process. All durable state lives in PostgreSQL;
uploads live on a filesystem path (`NEEV_UPLOAD_DIR`). The only in-process state is
the rate-limit window and the WebSocket connection registry. Both must be moved to
Redis before running more than one worker (see `docs/OPERATIONS.md`).

## Backend modules

| Path | Responsibility |
| --- | --- |
| `app/core/config.py` | Environment-driven settings, development-adapter guard |
| `app/core/database.py` | Engine, session factory, naming conventions, UTC helper |
| `app/core/security.py` | Argon2 passwords, JWT issue/verify, OTP and PIN hashing/encryption, signed share tokens |
| `app/core/rate_limit.py` | Sliding-window limiter dependency |
| `app/api/*.py` | HTTP and WebSocket surface; thin validation/authorisation layer |
| `app/services/auth_service.py` | OTP challenge lifecycle, token rotation, user bootstrap |
| `app/services/fare_service.py` | Quote computation, coupons, Power Pass, pricing lookup |
| `app/services/dispatch_service.py` | Eligibility, offer creation, accept/reject, assignment races |
| `app/services/ride_service.py` | Trip state transitions, arrival/PIN start/completion, serialisers |
| `app/services/payment_service.py` | Sandbox/Razorpay adapters, cash, refunds, wallet, webhooks |
| `app/services/ledger_service.py` | Double-entry postings and balances |
| `app/services/maps.py` | Demo/OSM routing and geocoding adapters |
| `app/services/realtime.py` | Connection manager, event envelope, broadcast + notification fan-out |
| `app/jobs/expiry.py` | Expires search requests, offers and Power Passes every 2 s |

Services raise domain errors that the API layer maps to the uniform error envelope:

```json
{ "error": { "code": "ride_unavailable", "message": "That ride is no longer available.", "details": null },
  "request_id": "…" }
```

## Data model

All primary keys are UUID strings; all timestamps are time-zone-aware UTC; all money
is stored as integer paise.

**Identity** — `users` (phone, role, status, token_version, is_demo),
`otp_challenges`, `refresh_tokens`, `passenger_profiles` (name, email, home/work
hints, rider PIN hash and encrypted PIN), `admin_users` (email, role:
`super_admin`/`admin`/`support`), `saved_addresses`,
`trusted_contacts`.

**Supply** — `captain_profiles` (verification status, online flag, last known
location, rating, earnings counters), `vehicles` (category, registration, model,
capacity), `captain_documents` (type, file path, review status, reviewer),
`captain_locations` (append-only breadcrumb trail), `service_areas` (centre, radius,
polygon-ish geofence).

**Demand and trips** — `ride_requests` (pickup/drop coordinates and labels,
category, quoted fare, status, expiry, idempotency key, payment method),
`ride_assignments` (one offer row per captain with distance and expiry),
`trips` (state machine, PIN hashes, timestamps, final fare, captain earnings),
`ride_events` (append-only event log used for WebSocket replay/audit),
`location_updates`.

**Money** — `fare_estimates`, `pricing_rules` (per category, optionally per service
area, effective-dated), `coupons`, `coupon_redemptions`, `power_pass_plans`,
`user_power_passes`, `payment_transactions`, `refunds`, `ledger_entries`,
`payout_requests`.

**Operations** — `support_tickets`, `ticket_messages`, `safety_incidents`,
`trip_shares`, `notifications`, `ratings`, `audit_logs`, `app_settings`,
`outbox_messages`.

### Key invariants

- A captain has at most one active trip (`captain_arriving`, `arrived`,
  `in_progress`); dispatch filters those captains out.
- Accepting a ride uses a conditional `UPDATE … WHERE status = 'searching'` so two
  captains cannot both win the same request. The loser receives `409`.
- A ride request carries a client idempotency key; repeats inside the window return
  the original request rather than creating a second one.
- Every fare quote snapshots its pricing rule version and line items; a later price
  change never rewrites history.
- Ledger entries are append-only. Payments, refunds, wallet top-ups and payouts post
  balanced entries; balances are derived, never stored twice.
- Trip start requires the rider's persistent PIN (verified server-side, not sent to
  the captain app).
- Admin actions that change state write an `audit_logs` row with actor, action,
  entity and redacted payload.

## Core flows

### 1. Login

1. `POST /auth/otp/request` normalises the phone number and creates an
   `otp_challenges` row (TTL, attempts, resend cooldown, per-IP rate limit).
2. The SMS adapter either writes to the development outbox or calls Twilio.
3. `POST /auth/verify` checks the OTP (constant-time, attempt-limited), creates the
   user and passenger profile on first login, marks the phone verified and returns
   an access/refresh pair.
4. Refresh tokens are stored hashed and rotated on use; logout revokes one, logout-all
   bumps `token_version` and invalidates every session.

### 2. Quote → request → assignment

1. `POST /fares/quote` geocodes nothing (client supplies coordinates), verifies the
   pickup/drop lie inside an active service area, requests a route (demo straight
   line or OSRM), applies base + distance + time + platform fee, night multiplier,
   coupon and Power Pass, then clamps to the category minimum fare.
2. `POST /rides/request` re-quotes with `use_power_pass=false`/coupon rules, stores
   the accepted quote, generates the trip PIN, then selects eligible captains:
   approved, online, fresh location (< 180 s), matching active vehicle category,
   within 5 km, not on an active trip.
3. Offers are ranked by distance then rating; each offer expires after 45 s or when
   the ride search times out (90 s).
4. Captain `POST /captain/offers/{ride_id}/accept` transitions the ride to
   `assigned`, creates the `trips` row in `captain_arriving`, expires sibling offers
   and broadcasts `ride.assigned`.

### 3. Trip lifecycle

```
searching ──accept──▶ assigned ──▶ captain_arriving ──arrived──▶ arrived
   │                     │                  │                        │
   │ timeout/cancel      │ cancel           │ cancel                 │ PIN start
   ▼                     ▼                  ▼                        ▼
expired              cancelled          cancelled                in_progress
                                                                     │ complete
                                                                     ▼
                                                                 completed
```

- Captain location pings are accepted only while a trip is active and are broadcast
  to the passenger; the passenger location is used for safety checks.
- Arrival and completion are captain actions; completion computes waiting charges,
  final fare, commission and captain earnings, then prompts payment.
- Cancellation before assignment is free; after assignment the configured
  cancellation fee applies and is recorded on the trip.
- Ratings are accepted once per completed trip and update the captain's aggregate.

### 4. Payments

- `POST /payments/rides/{id}` creates a transaction for cash, UPI/card sandbox, or
  wallet. The sandbox adapter exposes an explicit confirm endpoint; Razorpay uses
  order creation plus a signed webhook.
- Cash is confirmed by the captain/passenger and posts to the ledger immediately.
- Refunds require an admin decision, then post reversing ledger entries.
- Captain payouts are requested by the captain and approved by an admin;
  approved payouts debit the captain's available balance.

### 5. Safety

- `POST /safety/sos` creates a `safety_incidents` row tied to the active ride and
  enforces a per-user cooldown. It does **not** call emergency services; the UI is
  explicit about that.
- `POST /rides/{id}/share` mints a short-lived signed token; `/share/{token}` renders
  a server-side HTML snapshot with no authentication and no personal data beyond the
  trip context required.
- Admins resolve incidents with notes; resolution is audited.

### 6. Realtime

Clients connect to `/api/v1/ws?token=<access token>`. The socket validates the
token, role and `token_version`, sends `connection.ready`, then emits:
`ride.offer`, `ride.assigned`, `ride.arrived`, `ride.started`, `ride.completed`,
`ride.cancelled`, `ride.expired`, `trip.location`, `safety.sos`, plus
heartbeat/error frames. The server heartbeats every 25 s. Clients reconnect with
backoff and resynchronise through `GET /rides/{id}` and `GET /rides/{id}/locations`;
the REST API is authoritative.

## Clients

`apps/shared_package` is the single client SDK: typed models, `ApiClient` with
token refresh, `SessionStore` backed by `shared_preferences`, `RealtimeClient`,
design tokens, formatting helpers and shared widgets. Both Flutter apps depend on it
by path and add only screens and app-specific state.

The admin console is a conventional Vite SPA. `src/lib/api.ts` attaches the admin
JWT, normalises the error envelope and handles 401; `src/lib/auth.tsx` owns the
session; pages are grouped by domain and share the components in
`src/components/`.

## Deliberate boundaries

- No PostGIS: geofencing uses a centre/radius check and distances use haversine.
  This is adequate for the demo service area and keeps the deployment simple.
- No third-party push provider: notifications are persisted in-app and delivered
  over the WebSocket. Twilio SMS is the only outbound channel.
- No background queue: the expiry job runs inside the API process and is disabled
  with `NEEV_RUN_BACKGROUND_JOBS=false` for multi-worker deployments that use an
  external scheduler.
