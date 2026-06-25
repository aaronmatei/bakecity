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

1. Authentication with roles (customer, baker, admin)
2. Baker onboarding and KYC verification
3. Product discovery with geo-based search
4. Order management with quotes
5. Escrow payments via licensed PSP
6. Production tracking
7. Delivery management
8. Disputes and ratings

## Stack

**Backend:** Go + Gin + PostgreSQL + Redis + PostGIS
**Frontend:** Flutter + Riverpod + Dio + Go Router

## License

TBD
