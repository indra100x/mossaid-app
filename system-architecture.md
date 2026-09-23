# Mossaid — System Architecture

## 1. Overview

Mossaid is a two-sided marketplace connecting clients with craftspeople (wall painters, construction workers, architects, plumbers, electricians, etc.) across Algeria. This document defines the production-grade technical architecture: a **Flutter** mobile app (iOS + Android) backed by a **FastAPI** service layer, covering booking, in-app chat, escrow payments (Edahabia/CIB), an admin dashboard, and push notifications.

---

## 2. High-Level Architecture

```
┌─────────────────────┐        ┌─────────────────────┐
│   Flutter App        │        │  Admin Web Dashboard │
│  (iOS / Android)      │        │  (React/Next.js)     │
└──────────┬───────────┘        └──────────┬───────────┘
           │ HTTPS/WSS                        │ HTTPS
           ▼                                   ▼
┌─────────────────────────────────────────────────────┐
│                  API Gateway / Nginx                  │
│         (TLS termination, rate limiting)               │
└──────────────────────┬────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│                 FastAPI Application Layer               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │ Auth      │ │ Users/   │ │ Booking   │ │ Chat      │  │
│  │ Service   │ │ Profiles │ │ Service   │ │ (WS)      │  │
│  ├──────────┤ ├──────────┤ ├──────────┤ ├──────────┤  │
│  │ Payments/ │ │ Search/  │ │ Reviews   │ │ Notifi-   │  │
│  │ Escrow    │ │ Discovery│ │ Service   │ │ cations   │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
└───────┬────────────┬────────────┬────────────┬────────┘
        ▼             ▼            ▼             ▼
   PostgreSQL      Redis       S3-compatible   Celery
   (primary DB)  (cache/pubsub)  Storage       (async jobs)
                                              (queue: Redis/RabbitMQ)
        │
        ▼
  Read replica (reporting/admin dashboard queries)

External integrations:
  - SATIM / Chargily / CIB payment gateway (Edahabia, CIB card) — escrow
  - Firebase Cloud Messaging (push notifications)
  - SMS OTP provider (local Algerian SMS gateway)
  - Google Maps / Mapbox (geolocation, service-area matching)
```

---

## 3. Backend Stack

| Layer | Choice | Notes |
|---|---|---|
| API framework | **FastAPI** (Python 3.12) | async, Pydantic v2 for validation, OpenAPI auto-docs |
| ASGI server | Uvicorn + Gunicorn workers | behind Nginx, horizontal scaling |
| Database | PostgreSQL 16 | primary store; PostGIS extension for geo search (craftsman-near-me) |
| Cache / pub-sub | Redis 7 | session cache, rate limiting, chat pub/sub, Celery broker |
| Async task queue | Celery + Redis/RabbitMQ | payment webhooks, notification fan-out, image processing |
| Object storage | S3-compatible (AWS S3 or local Algerian provider) | profile photos, portfolio images, ID verification docs |
| Realtime chat | FastAPI WebSockets + Redis pub/sub | scales across multiple API instances |
| Search | PostgreSQL full-text + PostGIS, or OpenSearch if catalog grows | craftsman discovery by trade, location, rating |
| Auth | JWT (access + refresh tokens), OTP via SMS for phone verification | phone-first auth is standard in DZ market |
| Payments | SATIM/Chargily gateway integration (Edahabia, CIB) | escrow held until job completion confirmed by client |
| Admin dashboard | Separate Next.js/React app consuming the same API | role-gated (support, ops, finance, super-admin) |
| Infra | Docker + Docker Compose (staging), Kubernetes or managed VM cluster (production) | CI/CD via GitHub Actions |
| Monitoring | Sentry (errors), Prometheus + Grafana (metrics), structured logging (JSON logs → Loki/ELK) | |

---

## 4. Core Domain Modules (FastAPI routers)

1. **auth** — phone/OTP signup & login, JWT issuance/refresh, password reset (email optional), role assignment (client / craftsman / admin).
2. **users** — profile CRUD, craftsman trade categories, skills, service area (geo radius), portfolio photo uploads, ID/diploma verification upload for trust badges.
3. **discovery** — search & filter craftsmen by trade, location (PostGIS radius query), rating, price range, availability.
4. **bookings** — request → quote → accept → schedule → in-progress → completed → reviewed state machine; cancellation & dispute flows.
5. **chat** — WebSocket-based 1:1 messaging tied to a booking thread; message persistence in Postgres, delivery via Redis pub/sub for multi-instance scaling.
6. **payments** — escrow creation on booking confirmation, gateway webhook handling (SATIM/Chargily), release-on-completion, refund/dispute handling, craftsman payout scheduling.
7. **reviews** — rating + comment after job completion, aggregated into craftsman profile score.
8. **notifications** — push (FCM) + in-app notification center; triggered by booking state changes, new messages, payment events.
9. **admin** — verification queue (KYC/trade credential review), dispute resolution, user suspension, platform analytics, payout reconciliation.

---

## 5. Data Model (core entities)

- **User** (id, phone, role, name, language_pref, created_at, is_verified)
- **CraftsmanProfile** (user_id, trades[], bio, service_radius_km, base_location, hourly_rate, portfolio_photos[], verification_status, rating_avg)
- **Booking** (id, client_id, craftsman_id, trade, description, address, scheduled_at, status, price_agreed, escrow_status)
- **Payment** (id, booking_id, amount, gateway_ref, status[pending/held/released/refunded], created_at)
- **Message** (id, booking_id, sender_id, content, sent_at, read_at)
- **Review** (id, booking_id, rating, comment, created_at)
- **VerificationDocument** (id, user_id, doc_type, file_url, status, reviewed_by)

---

## 6. Security & Compliance

- HTTPS everywhere (TLS 1.3), HSTS.
- JWT short-lived access tokens (15 min) + rotating refresh tokens, stored securely on-device (Flutter secure storage).
- Rate limiting per IP/user on auth & payment endpoints (Redis-backed).
- Input validation via Pydantic schemas on every endpoint; SQLAlchemy ORM with parameterized queries (no raw SQL injection surface).
- PII encryption at rest for ID documents; signed, time-limited S3 URLs for private files.
- Payment data never touches our servers directly — tokenized via the gateway's hosted checkout/SDK to stay out of PCI-DSS scope.
- Role-based access control (RBAC) enforced via FastAPI dependencies on every admin/finance route.
- Audit log table for all admin actions (verification approvals, refunds, suspensions).

---

## 7. Deployment & Environments

- **Environments:** local (docker-compose) → staging → production, with separate DB instances and payment gateway sandbox/live keys.
- **CI/CD:** GitHub Actions — lint (ruff), type-check (mypy), tests (pytest) on every PR; build & push Docker image; deploy to staging automatically, production on tagged release.
- **Migrations:** Alembic, run as a pre-deploy step.
- **Scaling:** stateless FastAPI pods behind a load balancer; Redis for shared session/chat state so any pod can serve any request; Celery workers scaled independently for payment/notification load.
- **Backups:** automated daily PostgreSQL backups with point-in-time recovery; S3 versioning enabled on the media bucket.

---

## 8. Open Questions to Confirm

- Which payment gateway partner (SATIM directly, or an aggregator like Chargily/CIB PayLink) — this affects the exact escrow webhook contract.
- Hosting: Algerian data residency requirement, or cloud (AWS/GCP) acceptable?
- Arabic (with RTL support) and French — both required at launch, or phased?
