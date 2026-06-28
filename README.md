# BakeCity Project

A custom-bakery marketplace with escrow-style payments, production tracking, delivery, and ratings.

## Structure

```
.
├── backend/           # Go API (Gin)
├── frontend/          # Flutter app
├── Makefile           # Common commands
├── docker-compose.yml # Local development services
└── *.md               # Architecture documentation
```

## Quick Start

### Prerequisites
- Go 1.22+
- Flutter 3.0+
- Docker & Docker Compose
- PostgreSQL 14+
- Redis 7+

### Backend Development

```bash
# Start services
make services-start

# Run backend
make dev

# Run tests
make test
```

### Frontend Development

```bash
# Setup dependencies
make flutter-setup

# Run app
make flutter-run
```

### Database Migrations

```bash
# Run migrations
make migrate-up

# Rollback
make migrate-down
```

## Documentation

- [BakeCity Architecture](./bakecity-architecture.md) - System design and API spec
- [BakeFlow Architecture](./bakeflow-architecture.md) - Original design reference
- [Backend README](./backend/README.md) - Backend setup guide
- [Frontend README](./frontend/README.md) - Frontend setup guide

## Key Features (MVP)

The **backend is feature-complete** against the
[architecture spec](./bakecity-architecture.md) — all seven MVP phases plus the
cross-cutting payout and notifications layers are implemented; see the
[backend README](./backend/README.md#implementation-status) for the full status.
The Flutter frontend is scaffolded and not yet wired to the newer (phase 5–7)
endpoints.

1. ✅ Authentication with roles (customer, baker, admin)
2. ✅ Baker onboarding and KYC verification
3. ✅ Product discovery with geo-based search
4. ✅ Order management with versioned quotes, messaging, and scheduling
5. ✅ Escrow payments via licensed PSP (deposit hold, split, refunds, commission)
6. ✅ Production tracking with media (presigned uploads)
7. ✅ Delivery with proof-of-delivery gating final payment
8. ✅ Baker payouts (available-balance disbursement) and ledger balances
9. ✅ Disputes, admin resolution, ratings, and analytics
10. ✅ Notifications: in-app feed + push/SMS fan-out on lifecycle events

> External integrations (PSP, S3, FCM push, Africa's Talking SMS) currently run
> as stub simulators for local development; swap in real providers before
> production. Live WebSocket transport is not yet wired (the in-app feed is the
> durable channel).

## Stack

**Backend:** Go + Gin + PostgreSQL + Redis + PostGIS
**Frontend:** Flutter + Riverpod + Dio + Go Router

## License

TBD
