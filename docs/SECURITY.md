# Security

This document describes the controls implemented in the MVP, the threat model they
address, and the gaps that must be closed before a public launch. It is not a
compliance certification.

## Authentication and sessions

- **Passwords (admins)** — Argon2id with time cost 3, 64 MiB memory, parallelism 2.
  Verification is exception-safe; hashes are never logged.
- **OTP** — 6 digits from `secrets`, bound to a challenge id and HMAC-SHA256 hashed
  with the server secret before storage. Comparison uses `hmac.compare_digest`.
  Attempts, TTL, resend cooldown and per-IP rate limits are enforced server-side.
  The code is returned to the client only when the development adapter is enabled.
- **Access tokens** — JWT HS256 with `iss`-style claims (`sub`, `role`, `aud`, `typ`,
  `ver`, `iat`, `exp`, `jti`). Passenger and admin tokens use different audiences, so
  crossing surfaces fails closed.
- **Refresh tokens** — 48-byte opaque values; only a SHA-256 hash is stored. Every
  refresh rotates the token in a transaction; reuse of a revoked token is rejected.
- **Revocation** — logout revokes one refresh token; logout-all increments
  `users.token_version`, invalidating access and refresh tokens at once. The
  WebSocket also checks `token_version`.
- **Trip PIN** — four digits, generated with `secrets`, stored as an HMAC keyed by
  the trip id and encrypted with Fernet for the passenger's own retrieval. The PIN is
  verified server-side; the captain never receives it.

## Authorisation

- Dependency-based role gates (`passenger`, `captain`, `admin`, `super_admin`).
- Object-level checks on every ride, trip, payment, ticket, document and share:
  callers must be the ride passenger, assigned captain, document owner or an admin.
- Ride subscriptions on the WebSocket are acknowledged only for participants.
- Admin surfaces use a separate token audience and role checks; configuration,
  approvals, refunds, payouts, safety resolution and admin management require an
  elevated role.
- Every mutating admin action writes an `audit_logs` row (actor, action, entity,
  redacted detail, request id).

## Data protection

- Money is integer paise; balances are derived from append-only double-entry ledger
  rows. Operators cannot silently edit a balance.
- Trip share links are 48-byte random tokens; only an HMAC of the token is stored.
  Links expire (default 4 h), can be revoked, expose masked phone numbers, and show
  no full addresses beyond the first comma-separated area.
- Document downloads require an authenticated owner/admin request or a short-lived
  signed URL (default 5 min).
- Uploads are capped at 10 MB, restricted to JPEG/PNG by magic bytes (not just the
  client content type), written under a resolved root with generated keys, and
  rejected on path traversal.
- Database access uses bound SQLAlchemy parameters throughout; no string-built SQL.
- Error responses use stable codes and do not echo stack traces or SQL.
- Logs carry request ids and operational metadata, not OTPs, tokens or passwords.

## Abuse resistance

| Control | Scope |
| --- | --- |
| Sliding-window rate limit | OTP request/verify, admin login, share views |
| OTP attempts + resend cooldown | Per challenge |
| Ride idempotency key | Duplicate booking requests |
| Conditional ride acceptance | Two captains racing for one ride |
| Search/offer expiry | Stale demand and supply leakage |
| One active trip per captain | Dispatch eligibility filter |
| Location freshness | Stale captain heartbeats and client GPS |
| SOS cooldown | Per-user incident spam |
| Coupon per-user limit and total cap | Discount abuse |
| Wallet/ledger checks | Payments cannot overdraw |

## Threat model (abbreviated)

| Threat | Mitigation | Residual risk |
| --- | --- | --- |
| OTP brute force / SMS bombing | Attempt limits, TTL, per-IP rate limit, resend cooldown | Distributed IPs; add per-phone and carrier-level controls |
| Account takeover via SIM swap | OTP only | Add device binding, risk checks, step-up verification |
| Token theft | Short-lived access tokens, rotation, revocation, TLS in production | XSS in a compromised client; add CSP and secure storage |
| IDOR on rides/documents | Object-level ownership checks on every route | New endpoints must repeat the check |
| Payment tampering | Server-side quote snapshot, idempotency, signed webhook, ledger | Gateway misconfiguration; reconcile daily |
| Fake captain / document fraud | Document review workflow, admin decision + audit | Manual review quality; add KYC provider |
| Location privacy leak | Share tokens hashed/expiring, masked phones, participant-only live data | Screenshots by participants; policy and consent |
| Upload abuse | Size/MIME/magic-byte validation, generated paths, auth | Malware scanning not implemented |
| Repudiation | Audit log, ride event log, ledger | Log tampering at DB level; ship to append-only storage |
| DoS | Request limits on sensitive routes, pagination caps | No global WAF/quotas; put a WAF and proxy limits in front |

## Deployment hardening checklist

- [ ] `NEEV_APP_ENV=production`; startup guard must pass
- [ ] `NEEV_SECRET_KEY` from a secret manager, ≥ 32 random bytes, rotation plan tested
- [ ] TLS everywhere; HSTS, `X-Content-Type-Options`, `Referrer-Policy` and a CSP set
      at the reverse proxy (the app does not ship a security-header middleware)
- [ ] Exact CORS origins; never `*` with credentials
- [ ] PostgreSQL TLS, least-privilege role, encrypted backups, PITR
- [ ] Object storage private, server-side encryption, lifecycle rules
- [ ] Redis-backed rate limiting and WebSocket fan-out before multi-worker
- [ ] Trusted proxy configuration so `X-Forwarded-For` cannot be spoofed to bypass limits
- [ ] Webhook signature verification keys stored securely; replay window monitored
- [ ] Dependency scanning and image scanning in CI; pinned versions reviewed
- [ ] Log retention and PII minimisation agreed; no request bodies containing OTPs
- [ ] Data purge job for OTP challenges, expired refresh tokens, stale locations and
      share tokens
- [ ] Incident response, law-enforcement request handling and safety escalation
      procedures documented and rehearsed
- [ ] Independent penetration test before public launch

## Reporting

Security issues should be reported privately to the maintainers rather than opened
as public issues. Include reproduction steps, affected endpoint and impact.
