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
│   │                              #   idempotency (Redis), pspclient
│   └── pspclient/                 # PSPClient interface + StubClient
└── migrations/                    # golang-migrate SQL (PostGIS + pgcrypto)
```

Domains: `auth users bakers catalog search orders quotes messaging production
media delivery payments ledger disputes reviews notifications admin analytics`.

`auth` is fleshed out (register/login with bcrypt + HS256 JWT). The orders state
machine lives in `internal/orders/statemachine.go`. Most other handlers are
wired stubs returning `501 NOT_IMPLEMENTED` via `pkg.NotImplemented`.

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
