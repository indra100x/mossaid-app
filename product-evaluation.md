# Mossaid — Product Evaluation (Production-Level)

## 1. Product Summary

**Mossaid** is a marketplace mobile app connecting Algerian clients with skilled craftspeople — wall painters, construction workers, architects, plumbers, electricians, carpenters, and more. Target build: **full production release**, including chat, booking, escrow payments, admin dashboard, and notifications.

---

## 2. Target Users

| Persona | Needs |
|---|---|
| **Client** (homeowner, business, landlord) | Find a trustworthy, verified craftsman nearby, get quotes fast, pay safely, track job progress |
| **Craftsman** | Get discovered, receive booking requests, manage schedule, get paid reliably and on time |
| **Admin/Ops** | Verify craftsman identity/credentials, resolve disputes, monitor platform health & payouts |

---

## 3. Feature Set (Full Production Scope)

### Client-facing
- Phone/OTP signup, profile setup, language selection (Arabic/French)
- Browse/search craftsmen by trade, location radius, rating, price
- View craftsman profile: portfolio photos, verification badge, reviews, rate
- Request a booking (describe job, address, preferred date)
- In-app chat with the craftsman
- Escrow payment at booking confirmation (Edahabia/CIB)
- Track booking status (accepted → scheduled → in progress → completed)
- Release payment / raise a dispute after job completion
- Leave a rating & review
- Push notifications (booking updates, new messages, payment events)

### Craftsman-facing
- Profile & portfolio management, trade categories, service area, pricing
- Identity & trade credential upload for verification badge
- Receive and respond to booking requests (accept/decline/counter-quote)
- In-app chat
- Availability calendar
- Payout dashboard (pending, released, history)
- Ratings & reviews received

### Admin dashboard
- Verification queue (KYC + trade credentials)
- Dispute resolution workflow
- User management (suspend/reinstate)
- Payment/payout reconciliation
- Platform analytics: active users, bookings, GMV, completion rate, disputes rate

---

## 4. Non-Functional Requirements (Production Bar)

| Category | Requirement |
|---|---|
| **Availability** | 99.5%+ uptime target; graceful degradation if payment gateway is down (booking still creatable, payment retried) |
| **Performance** | API p95 response time < 300ms for read endpoints; search results < 1s |
| **Scalability** | Stateless API layer, horizontally scalable; designed to handle city-by-city rollout without re-architecture |
| **Security** | TLS everywhere, RBAC, PCI-DSS scope avoidance via gateway tokenization, encrypted PII at rest |
| **Localization** | Arabic (RTL) + French at launch; Darja-friendly copy tone |
| **Accessibility** | Minimum font scaling support, color-contrast compliant UI |
| **Offline resilience** | App should queue actions (e.g., chat messages) gracefully on poor connectivity — relevant given variable mobile network quality in parts of Algeria |
| **Observability** | Error tracking (Sentry), metrics dashboard, alerting on payment/booking failure spikes |

---

## 5. Trust & Safety (Critical for a Marketplace)

- Mandatory phone verification for all users.
- Craftsman identity + trade credential review before "Verified" badge is granted.
- Escrow model: client funds held until job marked complete, protecting both sides from non-payment/non-delivery.
- Dispute flow with admin arbitration and documented evidence (photos, chat log).
- Review system with verified-booking-only reviews (no fake reviews from non-booked users).
- Reporting/blocking mechanism for abusive users.

---

## 6. Success Metrics (KPIs)

| Metric | Why it matters |
|---|---|
| Booking completion rate | Core measure of marketplace health (requests → completed jobs) |
| GMV (Gross Merchandise Value) | Overall transaction volume through escrow |
| Craftsman verification rate | Trust signal — % of active craftsmen with verified badge |
| Time-to-first-response | How fast craftsmen respond to booking requests |
| Dispute rate | % of bookings escalated — should trend down over time |
| Repeat booking rate | Retention signal for both client and craftsman sides |
| Monthly active craftsmen / clients | Supply-demand balance tracking |

---

## 7. Monetization Options (to decide)

1. **Commission per booking** — % cut of escrow value on release (standard marketplace model).
2. **Subscription for craftsmen** — monthly fee for premium visibility/leads.
3. **Featured listing fees** — craftsmen pay to appear higher in search.
4. Hybrid of (1) + (3) is common for early-stage trade marketplaces.

---

## 8. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Low craftsman supply at launch (cold start) | Manually onboard & verify a seed group of craftsmen per city before public launch; city-by-city rollout |
| Payment gateway integration delays (SATIM/Chargily approval process) | Start gateway partner onboarding early; build payments module behind a feature flag so app can launch chat/booking first if needed |
| Trust concerns (fake craftsmen, no-shows) | Escrow + verification badges + review system + admin dispute process |
| Connectivity issues in some regions | Design chat/booking flows to queue and retry, not fail hard |
| Regulatory: payment/escrow handling may require compliance review | Confirm with legal counsel whether a fintech/escrow license or partnership with a licensed PSP is required in Algeria |

---

## 9. Suggested Rollout Phases

1. **Phase 0 — Foundation:** Auth, profiles, discovery, booking request flow (no payment yet), single city pilot.
2. **Phase 1 — Trust layer:** Verification badges, reviews, chat.
3. **Phase 2 — Payments:** Escrow integration, payout dashboard, dispute flow.
4. **Phase 3 — Admin & scale:** Full admin dashboard, analytics, multi-city expansion, push notifications at scale.

*(Note: the architecture in `system-architecture.md` is designed to support all phases from day one — phasing here is about release sequencing, not re-building.)*

---

## 10. Open Questions

- Which cities/regions for initial launch?
- Target commission rate, and is it charged to client, craftsman, or split?
- Is a legal/compliance review needed for holding client funds in escrow under Algerian financial regulation?
