# API reference

Base path: `/api/v1`. Interactive OpenAPI: `GET /docs`, schema: `GET /openapi.json`.

## Conventions

- **Auth** — `Authorization: Bearer <access_token>` on every private route. Admin
  routes use the same header but a separate token audience, so a passenger token can
  never call `/admin/*`.
- **Phone numbers** — normalised to E.164 (`+91XXXXXXXXXX`). Ten-digit Indian
  numbers starting 6–9 are accepted and normalised.
- **Money** — integer paise everywhere (`total_paise`); `*_display` fields are for UI.
- **Errors** — uniform envelope with HTTP status:
  ```json
  {"error":{"code":"ride_unavailable","message":"…","details":null},"request_id":"…"}
  ```
  Codes include `validation_error`, `not_authenticated`, `invalid_token`,
  `session_revoked`, `forbidden`, `rate_limited`, `not_found`, `conflict`,
  `out_of_service`, `coupon_*`, `pricing_unavailable`, `ride_*`, `captain_*`,
  `payment_*`, `insufficient_balance`, `internal_error`.
- **Pagination** — list routes accept `page` (1-based) and `page_size` (bounded) and
  return `{items,total,page,page_size}` unless noted.
- **Idempotency** — ride requests and payments require an `idempotency_key` (8–100
  chars). Replays return the original result.
- **Rate limits** — OTP request 12/10 min/IP, OTP verify 20/10 min/IP, admin login
  10/10 min/IP, share view 60/min/IP. Exceeding a limit returns `429` with
  `details.retry_after`.

## Public

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | Liveness + database/provider state (root, not `/api/v1`) |
| GET | `/share/{token}` | HTML trip-share page (root, signed short-lived token) |
| GET | `/api/v1/public/trips/share/{token}` | JSON trip snapshot for the same token |

## Authentication — `/auth`

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/otp/request` | – | Send OTP. Body `{phone, role}`; returns `challenge_id`, `expires_in`, `delivery`, and `dev_otp` only when the dev adapter is on |
| POST | `/otp/verify` | – | Verify `{phone, code, role, device_id?}` → `{access_token, refresh_token, expires_in, user}` |
| POST | `/refresh` | – | Rotate `{refresh_token}` → new token pair |
| POST | `/logout` | user | Revoke one refresh token |
| POST | `/logout-all` | user | Bump `token_version`, invalidating every session |
| GET | `/me` | user | Current profile with passenger/captain summary |

Access tokens live 15 minutes, admin tokens 30 minutes, refresh tokens 30 days.
Refresh tokens are stored hashed and rotated on every use.

## Catalog and locations — `/catalog`, `/locations`, `/passenger`

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/catalog/categories` | – | Active ride categories with capacity/icon/order |
| GET | `/catalog/config` | – | Client bootstrap: category list, service-area summary, feature flags |
| GET | `/locations/search?q=` | user | Forward geocode (demo dictionary or Nominatim) |
| GET | `/locations/reverse?lat=&lng=` | user | Reverse geocode |
| GET | `/locations/service-areas` | – | Active service areas for map display |
| GET | `/passenger/saved-addresses` | passenger | List saved addresses |
| POST | `/passenger/saved-addresses` | passenger | Add `{label,address,lat,lng}` |
| DELETE | `/passenger/saved-addresses/{id}` | passenger | Remove |
| GET | `/passenger/trusted-contacts` | passenger | List trusted contacts |
| POST | `/passenger/trusted-contacts` | passenger | Add `{name,phone,relationship?}` |
| DELETE | `/passenger/trusted-contacts/{id}` | passenger | Remove |

## Fares, Power Pass and wallet — `/fares`, `/passenger`

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/fares/quote` | passenger | `{category,pickup,drop,coupon_code?,use_power_pass?}` → itemised quote, route, `quote_token`, expiry |
| GET | `/passenger/profile` | passenger | Profile details |
| PUT | `/passenger/profile` | passenger | Update name/email/photo/home area |
| GET | `/passenger/power-pass` | passenger | Active pass, remaining rides, available plans |
| POST | `/passenger/power-pass/purchase` | passenger | Buy a plan with wallet balance |
| GET | `/passenger/wallet` | passenger | Wallet balance |
| GET | `/passenger/wallet/transactions` | passenger | Ledger-backed transaction history |

Quote rules: base + distance + time + platform fee, night multiplier 22:00–06:00 IST,
category minimum fare, then coupon and Power Pass discounts (never below zero).
The quote is a snapshot; `pricing_version` and line items are persisted with the ride.

## Rides — `/rides`, `/captain`

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/rides/request` | passenger | Create request; body includes category, pickup/drop, payment method, coupon, Power Pass flag, idempotency key, optional `quote_token` |
| GET | `/rides?status=` | passenger | Ride history |
| GET | `/rides/{id}` | participant | Full ride, trip, captain/vehicle summary |
| GET | `/rides/{id}/locations` | participant | Ordered breadcrumb trail |
| POST | `/rides/{id}/cancel` | passenger | Cancel with reason; fee flag after assignment |
| POST | `/rides/{id}/rate` | passenger | `{stars,comment?,tags?}` for a completed trip |
| POST | `/rides/{id}/share` | passenger | Mint share token `{duration_minutes?}` |
| GET | `/passenger/ride-events?since_id=` | passenger | Polling fallback for the event feed |
| GET | `/captain/offers` | approved captain | Open offers, nearest first |
| POST | `/captain/offers/{ride_id}/accept` | approved captain | Atomically claim the ride |
| POST | `/captain/offers/{ride_id}/reject` | approved captain | Decline an offer |
| GET | `/captain/trips` | captain | Trip history |
| POST | `/captain/trips/{id}/arrived` | captain | Mark arrival at pickup |
| POST | `/captain/trips/{id}/start` | captain | `{pin}` — verify rider PIN, start trip |
| POST | `/captain/trips/{id}/location` | captain | `{lat,lng,recorded_at,accuracy_m?,speed_mps?,heading?,source?}` |
| POST | `/captain/trips/{id}/complete` | captain | Complete at `{lat?,lng?}`, compute final fare |
| GET | `/captain/earnings` | captain | Earnings, commission, payout summary |
| POST | `/captain/payouts` | captain | Request payout `{amount_paise,method,destination}` |

Ride states: `searching`, `assigned`, `expired`, `cancelled`; trip states:
`captain_arriving`, `arrived`, `in_progress`, `completed`, `cancelled`.
Offers expire after 45 s, searches after 90 s.

## Captain onboarding — `/captain`

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/captain/profile` | captain | Profile, verification status, vehicles, documents |
| POST | `/captain/onboarding` | captain | Create draft: name, driving-licence number, PAN/Aadhaar last 4 |
| PUT | `/captain/profile` | captain | Update contact/payout UPI |
| POST | `/captain/vehicles` | captain | Add vehicle `{category,reg_number,make_model,color?,year?}` |
| DELETE | `/captain/vehicles/{id}` | captain | Deactivate a vehicle |
| POST | `/captain/documents` | captain | Multipart upload: `document_type`, `file` |
| GET | `/captain/documents/{id}/link` | owner/admin | Short-lived signed download URL |
| GET | `/captain/documents/{id}/download?token=` | – | Stream the document |
| POST | `/captain/availability` | captain | `{is_online,lat?,lng?}` toggle duty |
| POST | `/captain/location` | captain | Heartbeat while online |
| GET | `/captain/dashboard` | captain | Today's stats, rating, verification checklist |

## Payments — `/payments`

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/methods` | user | Enabled methods and provider mode |
| POST | `/rides/{ride_id}` | participant | Create payment `{method,idempotency_key}` |
| POST | `/{payment_id}/sandbox-confirm` | participant | Sandbox success/failure `{outcome,idempotency_key}` |
| POST | `/rides/{ride_id}/cash-confirm` | participant | Record cash settlement |
| GET | `/history` | user | Payment history |
| POST | `/{payment_id}/refund` | passenger/admin | Request refund with reason |
| POST | `/wallet/topup` | passenger | Sandbox wallet top-up |
| POST | `/webhooks/razorpay` | signature | Razorpay webhook (`X-Razorpay-Signature`) |

## Safety — `/safety`

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/features` | – | Safety feature catalogue shown in the apps |
| POST | `/sos` | participant | Raise `{ride_request_id?,lat?,lng?,press_hold_ms,note?}` |
| POST | `/sos/{id}/cancel` | owner | Cancel a false alarm |
| GET | `/sos/active` | user | Active incident, if any |
| GET | `/sos/history` | user | Incident history |

SOS raises an operations alert; it does not contact emergency services. The UI and
API response both say so.

## Support and notifications — `/tickets`, `/notifications`

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/tickets` | user | Create ticket `{category,subject,description,ride_request_id?}` |
| GET | `/tickets` | user | Own tickets |
| GET | `/tickets/{id}` | owner/admin | Thread |
| POST | `/tickets/{id}/messages` | owner/admin | Reply `{body}` |
| GET | `/notifications` | user | Inbox + unread count |
| POST | `/notifications/read` | user | Mark `{notification_ids}` or all read |

## Admin — `/admin` (bearer token, separate audience)

| Method | Path | Role | Purpose |
| --- | --- | --- | --- |
| POST | `/auth/login` | – | `{email,password}` → admin token |
| GET | `/auth/me` | any | Current admin |
| GET | `/dashboard` | any | KPIs, time series, recent activity |
| GET | `/passengers` | any | Search/list passengers |
| GET | `/passengers/{id}` | any | Passenger detail + rides |
| POST | `/passengers/{id}/status` | admin/super | Suspend/reactivate |
| GET | `/captains` | any | Filter by verification/online/category |
| GET | `/captains/{id}` | any | Captain detail, vehicles, documents |
| POST | `/captains/{id}/decision` | admin/super | Approve/reject with reason |
| POST | `/captains/{id}/documents/{doc}/review` | admin/super | Per-document decision |
| POST | `/captains/{id}/status` | admin/super | Suspend/reactivate |
| GET | `/documents/{id}/link` | any | Signed document URL |
| GET | `/rides` | any | Filter by status/category/city/date |
| GET | `/rides/{id}` | any | Ride + trip + events + payment |
| GET | `/pricing` | any | Pricing rules |
| POST | `/pricing` | admin/super | Create effective-dated rule |
| PATCH | `/pricing/{id}` | admin/super | Update/deactivate |
| GET | `/categories` | any | Categories |
| PATCH | `/categories/{id}` | admin/super | Edit category |
| GET | `/coupons` | any | Coupons and redemptions |
| POST | `/coupons` | admin/super | Create coupon |
| PATCH | `/coupons/{id}` | admin/super | Edit/deactivate |
| GET | `/power-pass` | any | Plans and active passes |
| PATCH | `/power-pass/{id}` | admin/super | Edit plan |
| GET | `/tickets` | any | Support queue |
| GET | `/tickets/{id}` | any | Thread |
| POST | `/tickets/{id}/reply` | any | Operator reply |
| POST | `/tickets/{id}/resolve` | any | Resolve with note |
| GET | `/payments` | any | Transactions |
| GET | `/refunds` | any | Refund queue |
| POST | `/refunds/{id}/decision` | admin/super | Approve/reject |
| GET | `/payouts` | any | Payout queue |
| POST | `/payouts/{id}/decision` | admin/super | Approve/reject |
| GET | `/service-areas` | any | Areas |
| POST | `/service-areas` | admin/super | Create area |
| PATCH | `/service-areas/{id}` | admin/super | Edit/activate |
| GET | `/settings` | any | App settings |
| PUT | `/settings/{key}` | super | Upsert setting |
| GET | `/audit-logs` | super | Filterable audit trail |
| GET | `/safety-incidents` | any | Safety queue |
| POST | `/safety-incidents/{id}/resolve` | admin/super | Resolve with note |
| GET | `/admins` | super | Admin accounts |
| POST | `/admins` | super | Create admin |
| GET | `/exports/rides.csv` | any | Streaming CSV export |

Admin roles: `super_admin` and `admin` (the seed also creates a `support` account
for read-only review). Configuration changes, approvals, refunds, payouts, safety
resolution and admin management require `super_admin` or `admin`; queue reads and
ticket replies are open to any authenticated admin. Every mutating admin action
writes an audit entry.

## WebSocket — `/api/v1/ws?token=<access_token>`

Connection requires a valid, unrevoked access token. Close code `4401` means
re-authenticate. The server sends `connection.ready`, a `heartbeat` every 25 s, and
responds to client messages:

```json
{"action":"ping"}
{"action":"subscribe","ride_id":"<uuid>"}
```

`subscribe` acknowledges only if the caller is the ride's passenger or assigned
captain. Event envelope:

```json
{"event_id":42,"type":"ride.assigned","entity_id":"<ride_id>",
 "timestamp":"2026-10-22T12:00:00+00:00","payload":{...}}
```

Event types: `connection.ready`, `heartbeat`, `pong`, `subscription.ack`,
`ride.offer`, `ride.assigned`, `ride.arrived`, `ride.started`, `ride.completed`,
`ride.cancelled`, `ride.expired`, `trip.location`, `safety.sos`, `error`.
Reconnect with backoff and re-fetch `GET /rides/{id}` for missed state.
