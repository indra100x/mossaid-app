# Mossaid — Agent Build Plan

Plan for driving an AI coding agent (e.g. Claude Code) through building Mossaid, phase by phase, with the prompts to give it at each step. Follows the phases defined in `product-evaluation.md` and the stack defined in `system-architecture.md`.

---

## 0. Before Starting — Setup Prompt

Give the agent both other documents as context first.

```
Read system-architecture.md and product-evaluation.md in this repo.
Set up the initial project structure:
- /backend — FastAPI app (Python 3.12), using the module layout from
  system-architecture.md section 4 (auth, users, discovery, bookings, chat,
  payments, reviews, notifications, admin as separate routers).
- /app — Flutter app (iOS + Android).
- /admin — Next.js admin dashboard.
- docker-compose.yml wiring Postgres, Redis, and the FastAPI app for local dev.
- Alembic set up for migrations.
- GitHub Actions CI: lint (ruff), type-check (mypy), test (pytest) on every PR.
Do not implement features yet — just the skeleton, health-check endpoint,
and a passing CI pipeline. Confirm the skeleton runs locally before moving on.
```

---

## Phase 0 — Foundation (Auth, Profiles, Discovery, Booking Request)

```
Implement Phase 0 of Mossaid, backend first:

1. auth router: phone-number signup, OTP verification (stub the SMS
   provider behind an interface so it can be swapped later), JWT
   access+refresh token issuance, /me endpoint.
2. users router: profile CRUD for both client and craftsman roles;
   craftsman-specific fields (trades[], bio, service_radius_km,
   base_location as lat/lng, hourly_rate).
3. discovery router: search craftsmen by trade + location radius
   using PostGIS; filters for rating and price range.
4. bookings router: create a booking request (client → craftsman,
   trade, description, address, preferred date), and a state machine
   for status transitions (requested → accepted/declined → scheduled).
   No payment yet.

Write Pydantic schemas for every request/response. Write pytest tests
for each endpoint including auth failure and validation-error cases.
Then implement the equivalent Flutter screens: onboarding/OTP login,
profile setup, craftsman search/browse, craftsman profile view,
booking request form.

Stop and summarize what's done + any deviations from the architecture
doc before starting Phase 1.
```

---

## Phase 1 — Trust Layer (Verification, Reviews, Chat)

```
Implement Phase 1:

1. Verification: endpoint for craftsmen to upload ID + trade credential
   documents to S3-compatible storage (signed upload URLs); admin-only
   endpoint to approve/reject, setting verification_status; a
   "Verified" badge exposed on the public profile.
2. Reviews: after a booking reaches "completed", allow the client to
   submit a rating (1-5) + comment; aggregate into the craftsman's
   rating_avg. Reject reviews for bookings that aren't completed or
   don't belong to the reviewer.
3. Chat: WebSocket endpoint scoped to a booking thread; persist
   messages in Postgres; use Redis pub/sub so messages reach the
   right connected client regardless of which API pod they're on.
   Add read-receipt tracking.

Build the matching Flutter screens: verification upload flow,
review submission after job completion, real-time chat screen with
message history and typing/read indicators.

Write tests for the WebSocket flow (connect, send, receive, disconnect)
and for the review authorization rules. Report back before Phase 2.
```

---

## Phase 2 — Payments (Escrow)

```
Implement Phase 2 — this is the highest-risk phase, be careful with
money handling:

1. Integrate the chosen payment gateway (SATIM/Chargily — confirm
   which one is finalized before writing this) for Edahabia/CIB
   card payments, using their hosted checkout/SDK so raw card data
   never touches our servers.
2. On booking confirmation, create an escrow-held payment record;
   handle the gateway's webhook to update payment status
   (pending → held → released/refunded).
3. Add a "release payment" action for the client after job completion,
   and a "raise dispute" action instead, which freezes the escrow
   and creates an admin task.
4. Add a craftsman payout view (pending/released/history) — actual
   payout disbursement can be a manual admin-triggered step for v1.
5. Idempotency: webhook handlers must be idempotent (gateway may
   retry delivery) — use the gateway's event ID to dedupe.

Write tests including: webhook replay (idempotency), dispute freezing
escrow correctly, refund path. Do not merge this phase without
explicit human review of the payment code paths.
```

---

## Phase 3 — Admin & Scale

```
Implement Phase 3:

1. Admin dashboard (Next.js): verification queue, dispute resolution
   UI, user suspension, payout reconciliation view, analytics
   (bookings, GMV, verification rate, dispute rate — per
   product-evaluation.md section 6).
2. Push notifications: FCM integration, triggered on booking status
   change, new chat message, payment event. Add an in-app
   notification center as a fallback for users without push enabled.
3. RBAC: lock every /admin/* route behind role checks (support, ops,
   finance, super-admin tiers).
4. Add structured logging + Sentry error tracking + a
   Prometheus /metrics endpoint.

Write an audit log for every admin action. Report deviations and a
final production-readiness checklist referencing section 4 of
product-evaluation.md (non-functional requirements) before declaring
this phase done.
```

---

## Working Agreements for the Agent (apply throughout)

- **One phase at a time.** Don't start the next phase's code until the current one's tests pass and you've summarized what was built.
- **Never guess on money/legal questions.** Payment gateway choice, commission rate, and compliance requirements are flagged as open questions in the other two docs — stop and ask rather than assuming.
- **Every new endpoint needs a test.** No exceptions for auth or payment code.
- **Keep the architecture doc in sync.** If an implementation detail diverges from `system-architecture.md` (e.g. a different queue library), update the doc in the same PR.
- **Localization from day one.** All user-facing strings go through the Flutter localization system (Arabic RTL + French) even in Phase 0 — retrofitting i18n later is expensive.
- **Small PRs.** Each router/module implemented above should be its own PR, not one giant commit per phase.
