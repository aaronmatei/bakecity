# BakeCity Makefile

.PHONY: help
help:
	@echo "BakeCity - Backend commands"
	@echo "================================"
	@echo "Backend:"
	@echo "  make dev              - Run backend in development"
	@echo "  make build            - Build backend binary"
	@echo "  make test             - Run backend tests"
	@echo "  make docker-build     - Build Docker image"
	@echo "  make docker-run       - Run Docker container"
	@echo "  make migrate-up       - Run database migrations"
	@echo "  make migrate-down     - Rollback database migrations"
	@echo ""
	@echo "Frontend:"
	@echo "  make flutter-setup    - Setup Flutter dependencies"
	@echo "  make flutter-run      - Run Flutter app"
	@echo "  make flutter-build    - Build Flutter app"
	@echo ""
	@echo "Database:"
	@echo "  make db-start         - Start PostgreSQL in Docker"
	@echo "  make db-stop          - Stop PostgreSQL"
	@echo "  make redis-start      - Start Redis in Docker"
	@echo "  make redis-stop       - Stop Redis"

# Backend targets
.PHONY: dev
dev:
	cd backend && go run cmd/api/main.go

.PHONY: build
build:
	cd backend && go build -o bakecity ./cmd/api

.PHONY: test
test:
	cd backend && go test -v ./...

.PHONY: docker-build
docker-build:
	docker build -t bakecity:latest -f backend/Dockerfile backend/

.PHONY: docker-run
docker-run:
	docker run -p 8080:8080 --env-file backend/.env bakecity:latest

.PHONY: migrate-up
migrate-up:
	migrate -path backend/migrations -database "$$DATABASE_URL" up

.PHONY: migrate-down
migrate-down:
	migrate -path backend/migrations -database "$$DATABASE_URL" down

# Grant the admin role bit (4) to an existing user by phone, e.g.
#   make seed-admin PHONE=+254700000000
# The user must log in again afterwards to obtain a token carrying the role.
.PHONY: seed-admin
seed-admin:
	@test -n "$(PHONE)" || { echo "usage: make seed-admin PHONE=+2547..."; exit 1; }
	docker compose exec -T postgres psql -U bakecity -d bakecity \
		-c "UPDATE users SET role_mask = role_mask | 4 WHERE phone = '$(PHONE)';"

# Frontend targets
.PHONY: flutter-setup
flutter-setup:
	cd frontend && flutter pub get

.PHONY: flutter-run
flutter-run:
	cd frontend && flutter run

.PHONY: flutter-build
flutter-build:
	cd frontend && flutter build apk

# Database / service targets (Postgres+PostGIS and Redis via docker-compose).
# Host Postgres uses 5432 and another project's Redis uses 6379 on this box,
# so compose publishes Postgres on 5435 and Redis on 6380 — see docker-compose.yml.
.PHONY: db-start
db-start:
	docker compose up -d postgres

.PHONY: db-stop
db-stop:
	docker compose stop postgres

.PHONY: redis-start
redis-start:
	docker compose up -d redis

.PHONY: redis-stop
redis-stop:
	docker compose stop redis

.PHONY: services-start
services-start: db-start redis-start
	@echo "Started PostgreSQL and Redis"

.PHONY: services-stop
services-stop: db-stop redis-stop
	@echo "Stopped PostgreSQL and Redis"
