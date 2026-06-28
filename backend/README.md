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
  best-effort push/SMS fan-out, emitted from the order lifecycle (quote, deposit,
  production, delivery, completion, dispute, payout). Money-critical events also
  go out over SMS.

Money movements are double-entry through `internal/ledger`; payment, webhook, and
payout paths are idempotent (Redis reservation + per-order ledger guards). The
PSP, S3, and FCM/SMS flows run against stub clients in dev — point
`DATABASE_URL` at a migrated database and run `go test ./...` to exercise the
DB-gated integration tests (e.g. the full escrow-to-payout lifecycle).

Not yet built: live WebSocket transport for realtime push (the in-app feed is
the durable channel), and the per-stage cancellation refund percentages from §7
(refund execution is a manual admin action returning the held deposit).

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
