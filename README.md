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

# Or run backend directly (requires local Postgres/Redis)
cd backend
pip install -e ".[dev]"
ruff check . && mypy . && pytest -q
uvicorn app.main:app --reload

# Flutter
cd app
flutter pub get && flutter analyze && flutter test
flutter run

# Admin
cd admin
npm ci && npm run lint && npm run build
npm run dev  # http://localhost:3000
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
