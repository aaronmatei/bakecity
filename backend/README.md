# BakeCity Backend

Go API for the BakeCity custom-bakery marketplace with M-Pesa escrow payments.

Stack: Gin (HTTP), pgx/v5 + pgxpool (Postgres/PostGIS), go-redis/v9 (cache,
idempotency), golang-jwt/v5 (auth), bcrypt (password hashing).

## Project Structure

```
backend/
├── cmd/api/                       # Entry point: config, deps, graceful shutdown
├── internal/
│   ├── config/                    # Env-driven configuration
│   ├── platform/database/         # pgxpool connection helper
│   ├── platform/cache/            # redis client helper
│   ├── middleware/                # RequestID, Recovery, Logger, Auth, RequireRole
│   ├── server/                    # Router + dependency wiring
│   └── <domain>/                  # One package per domain, layered:
│       ├── model.go               #   structs + status/enum consts
│       ├── repository.go          #   Repository{*pgxpool.Pool} + queries
│       ├── service.go             #   Service{repo,...} business logic
│       └── handler.go             #   Handler{svc} + RegisterRoutes(rg)
├── pkg/                           # Shared: errors, httpx, uuid, validation,
│   │                              #   idempotency (Redis)
│   ├── pspclient/                 # PSPClient interface + StubClient
│   └── storage/                   # Presigner interface + StubPresigner (S3)
└── migrations/                    # golang-migrate SQL (PostGIS + pgcrypto)
```

Domains: `auth users bakers catalog search orders quotes messaging production
media delivery payments ledger disputes reviews notifications admin analytics`.

Every domain is implemented end to end (see **Implementation status**).
`auth` uses bcrypt + HS256 JWT; the orders state machine lives in
`internal/orders/statemachine.go`. External integrations — `pkg/pspclient`
(PSP), `pkg/storage` (S3), and the notifications `Sender` (FCM / Africa's
Talking) — ship as in-process **stub simulators** for local development; swap in
real providers before production.

## Implementation status

The backend is feature-complete against the architecture spec. The MVP phases
follow [the phasing plan](../bakecity-architecture.md#11-mvp-phasing):

| Phase | Scope | Status |
|---|---|---|
| 1 | Auth, roles, baker onboarding/verification, minimal admin | ✅ |
| 2 | Bakers, catalog (categories), discovery/search + geo | ✅ |
| 3 | Orders, versioned quotes, messaging, scheduling/lead-time | ✅ |
| 4 | Payments via PSP — escrow hold, split, payout, refunds, commission | ✅ |
| 5 | Production timeline + media (presigned uploads) | ✅ |
| 6 | Delivery + proof-of-delivery wired to payout release | ✅ |
| 7 | Ratings, dispute hardening, analytics | ✅ |

Beyond the phases, the cross-cutting pieces from the spec are in place:

- **Baker payouts** (§8): `POST /payouts` disburses a baker's available balance
  via the PSP, books the ledger debit (`baker_available → payouts`), and records
  it; `GET /payouts/balance` shows available / held / paid-out.
- **Notifications & events** (§10): a durable in-app feed (`/notifications`) plus
  realtime WebSocket push and best-effort push/SMS fan-out, emitted from the
  order lifecycle (quote, deposit, production, delivery, completion, dispute,
  payout). Money-critical events also go out over SMS.
- **Realtime transport** (§2, §10): `GET /ws/notifications?token=<jwt>` upgrades
  to a WebSocket; a per-user connection hub fans events out, using Redis pub/sub
  so an event raised on any instance reaches that user's connections everywhere
  (in-process delivery when Redis is absent).
- **Cancellation refund matrix** (§7): `POST /orders/:id/cancel` applies the
  graduated split to the held deposit and settles it on the ledger. A customer
  may cancel through IN_PRODUCTION (deposit minus a processing fee before
  production; a 50/50 forfeit once in production, baker's share net of
  commission); once READY they must dispute. A baker (can't fulfil) or admin may
  cancel any pre-DELIVERED stage with a full refund. Percentages are platform
  defaults today; per-baker overrides are a future extension.

Money movements are double-entry through `internal/ledger`; payment, webhook, and
payout paths are idempotent (Redis reservation + per-order ledger guards). The
PSP, S3, and FCM/SMS clients are stub simulators in dev — point `DATABASE_URL`
at a migrated database and run `go test ./...` to exercise the DB-gated
integration tests (e.g. the full escrow-to-payout lifecycle).

The backend now covers the architecture spec end to end. Remaining work is
operational hardening (real PSP/S3/FCM/SMS providers, per-baker refund config)
and wiring the Flutter frontend to the newer endpoints.

## Getting Started

### Prerequisites
- Go 1.23+
- PostgreSQL 14+ with the PostGIS extension
- Redis 7+

### Setup

1. Copy `.env.example` to `.env` and update values.
2. Install dependencies: `go mod download`
3. Run migrations (golang-migrate CLI):
   ```bash
   migrate -path migrations -database "$DATABASE_URL" up
   ```
4. Start the server:
   ```bash
   go run ./cmd/api
   ```

The server boots even if Postgres/Redis are unavailable (degraded dev mode);
data-backed endpoints return errors until the dependencies are reachable.

### Environment

Key variables (see `.env.example`): `PORT`, `ENV`, `DATABASE_URL`, `REDIS_URL`,
`JWT_SECRET`, `AWS_*`, `PSP_*`, `FCM_SERVER_KEY`, `AT_API_KEY`, `AT_USERNAME`,
`ADMIN_EMAIL`.

## API

All routes are mounted under `/api/v1` (plus `GET /health`).

- Public: `auth/*`, `search/*`, `payments/webhook`
- Authenticated (JWT bearer): users, bakers, catalog, orders, quotes, messaging,
  production, media, delivery, payments, disputes, reviews, notifications
- Admin (JWT + admin role bit): `admin/*`, `analytics/*`

RBAC uses the `users.role_mask` bitmask: `1=customer, 2=baker, 4=admin`.

## Development

```bash
go build ./...     # compile
go vet ./...       # static checks
go test ./...      # tests
```

### Docker
```bash
docker build -t bakecity .
docker run -p 8080:8080 bakecity
```

See [bakecity-architecture.md](../bakecity-architecture.md) for the full design.
