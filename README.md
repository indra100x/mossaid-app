# Mossaid — Marketplace

Two-sided marketplace connecting clients with craftspeople across Algeria.

## Architecture
See `system-architecture.md` (section 4 for FastAPI module layout) and `product-evaluation.md`.

## Project Structure

```
.
├── backend/            # FastAPI (Python 3.12) — see backend/README.md
│   ├── app/
│   │   ├── main.py
│   │   ├── core/       # config, database
│   │   ├── api/        # health
│   │   └── modules/    # auth, users, discovery, bookings, chat, payments, reviews, notifications, admin
│   ├── alembic/        # migrations
│   └── tests/          # pytest
├── app/                # Flutter (iOS + Android) — see app/README.md
├── admin/              # Next.js admin dashboard — see admin/README.md
├── docker-compose.yml  # Postgres 16 + Redis 7 + FastAPI
└── .github/workflows/ci.yml  # ruff, mypy, pytest per PR
```

## Local Dev

```bash
# Backend API + DB + Redis
docker compose up --build
# API at http://localhost:8000 — docs http://localhost:8000/docs — health http://localhost:8000/health
# First run (or after pulling new migrations):
docker compose exec api alembic upgrade head

# Or run backend directly (requires local Postgres/Redis)
cd backend
pip install -e ".[dev]"
ruff check . && mypy . && pytest -q
uvicorn app.main:app --reload

# Flutter
cd app
flutter pub get && flutter analyze && flutter test
flutter run

# Admin (no terminal skills needed — just log in with the dashboard form)
cd admin
npm ci && npm run lint && npm run build
npm run dev  # http://localhost:3000 — login: admin / polo@2013 (local default)
# Session renews itself; logout is in the header. Prod credentials come from
# ADMIN_USERNAME / ADMIN_PASSWORD_HASH env (bcrypt hash, see backend/.env.example).
```

## Migrations

```bash
cd backend
alembic revision --autogenerate -m "describe change"
alembic upgrade head
# Inside Docker:
docker compose exec api alembic upgrade head
```

## CI

GitHub Actions runs on every PR to `main`:
- backend: `ruff check`, `mypy`, `pytest`
- admin: `npm run lint`, `npm run build`
- app: `flutter analyze`, `flutter test`

## Production Checklist

```bash
# 1. Secrets — export in the deploy env (never commit real values)
export JWT_SECRET_KEY="..." SENTRY_DSN="..." \
  FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}' \
  ADMIN_USERNAME="admin" ADMIN_PASSWORD_HASH="$(python -c "from app.core.security import hash_password; print(hash_password('...'))")" \
  CHARGILY_API_KEY="..." CHARGILY_API_SECRET="..." \
  CHARGILY_WEBHOOK_SECRET="..." CHARGILY_SANDBOX="false"
# See backend/.env.example for the full list; docker-compose.yml passes
# these through with safe local defaults (Sentry/FCM disabled when empty).

# 2. Sandbox money-path verification (human review required before going live)
cd backend && pytest tests/test_e2e_money_paths.py -v
# Covers: checkout(pending) → webhook paid(held/escrow) → release, dispute
# freeze → admin resolve, webhook replay idempotency, notifications, audit.

# 3. Observability
docker compose --profile observability up prometheus  # :9090, scrapes api:8000/metrics
# Alert rules (infra/alerts.yml): ApiDown, High5xxRate, PaymentDisputeSpike —
# wire Prometheus Alertmanager to your paging channel.

# 4. TLS edge gateway (rate limits auth + payments, blocks external /metrics)
openssl req -x509 -newkey rsa:2048 -keyout infra/certs/privkey.pem \
  -out infra/certs/fullchain.pem -days 90 -nodes -subj "/CN=example.com"  # local only
# Prod: replace with a real cert (e.g. Let's Encrypt) at the same paths.
docker compose --profile gateway up nginx  # :80 → https, :443 TLS
```
