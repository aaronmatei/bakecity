# BakeCity — App Architecture & Spec

A custom-bakery marketplace with escrow-style payments, production tracking, delivery, and ratings. This is an opinionated revision of the original BakeFlow design, with the unhappy paths, scheduling, discovery, messaging, and the Kenya-specific payment reality built in.

**Business model:** 5% platform commission per completed order, taken at settlement. Deposit held before production, balance after delivery confirmation.

---

## 1. Guiding decisions

These shape everything else, so they come first.

1. **You do not custody money.** Holding/collecting third-party funds in Kenya triggers PSP licensing under the National Payment System Act. A licensed provider (M-Pesa Daraja + Pesapal / Flutterwave / Cellulant) collects, holds, splits, and settles. BakeFlow records the *ledger and intent*; the PSP moves the cash. Confirm **delayed split-release** support with your provider before building.
2. **The ledger is double-entry.** Every money movement is balanced across accounts. This is the only sane way to reconcile against the PSP and compute partial refunds.
3. **Disputes and an admin/ops surface exist from day one**, not phase 5. You will hand-resolve disputes and approve bakers manually for a long time.
4. **Delivery confirmation is the gate** that unlocks final payment and baker payout.
5. **Orders are date-bound.** Scheduling, lead time, and capacity are first-class, not afterthoughts.

---

## 2. System architecture

```
            Flutter app (customer + baker roles)
                        │
                 HTTPS / WebSocket
                        │
                   Go API (Gin)
                        │
     ┌──────────┬───────┼────────┬─────────────┐
     │          │       │        │             │
 PostgreSQL   Redis    S3    Licensed PSM    FCM + SMS
 (+ PostGIS) (cache,  (media, (Daraja,      (push +
             pub/sub, presigned Pesapal/    Africa's
             rate-    uploads) Flutterwave) Talking)
             limit)
```

- **PostgreSQL + PostGIS** — primary store; PostGIS for "bakers who deliver to me".
- **Redis** — cache, rate limiting, WebSocket pub/sub fan-out, idempotency-key store.
- **S3** — media; clients upload directly via presigned URLs (API never proxies video bytes).
- **PSP** — custody, collection (M-Pesa STK push + card), split payout, settlement webhooks.
- **FCM** for push; **Africa's Talking** for transactional SMS fallback (high-trust in KE).

---

## 3. Backend layout (Go)

Changes from the original in **bold**.

```
backend/
├── cmd/
│   └── api/main.go
├── internal/
│   ├── auth/            # JWT, sessions, RBAC (customer / baker / admin)
│   ├── users/
│   ├── bakers/          # profile, KYC/verification, availability, lead-time, capacity
│   ├── catalog/         # products + categories/tags + images   (was "products")
│   ├── search/          # discovery, filters, geo (PostGIS)          ← NEW
│   ├── orders/          # order lifecycle + state machine
│   ├── quotes/          # versioned quotes
│   ├── messaging/       # customer↔baker threads, attachments       ← NEW
│   ├── production/      # stage updates
│   ├── media/           # presigned uploads, thumbnails
│   ├── delivery/        # dispatch, proof-of-delivery, confirmation
│   ├── payments/        # PSP integration: collect, split, payout, webhooks
│   ├── ledger/          # double-entry accounts + entries  (was "wallets")
│   ├── disputes/        # raise, freeze, arbitrate, resolve           ← NEW
│   ├── reviews/
│   ├── notifications/   # push + SMS + in-app + WebSocket
│   ├── admin/           # baker approval, dispute resolution, refunds, payouts ← NEW
│   └── analytics/
├── pkg/                 # httpx, errors, validation, idempotency, pspclient
├── migrations/          # golang-migrate
├── configs/
├── scripts/
└── Dockerfile
```

**Stack notes:** Gin is fine. Use `pgx` (+ optionally `sqlc` for typed queries), `golang-migrate` for migrations. Put **idempotency keys** on every payment-mutating endpoint and on PSP webhook handlers — webhooks retry, and double-crediting a baker is the worst bug you can ship.

---

## 4. Frontend layout (Flutter)

Your structure was good; keep it. Additions in **bold**.

```
frontend/lib/
├── core/            # constants, theme, errors, storage, helpers
├── services/        # api, auth, upload, payment, notification, websocket, sms_status
├── routes/app_router.dart
├── widgets/
├── features/
│   ├── auth/
│   ├── onboarding/        # baker KYC/verification flow            ← NEW
│   ├── customer/
│   ├── baker/
│   ├── discovery/         # search, filters, map of nearby bakers  ← NEW
│   ├── products/
│   ├── orders/
│   ├── quotes/
│   ├── messaging/         # in-order chat                          ← NEW
│   ├── production/
│   ├── delivery/
│   ├── payments/
│   ├── disputes/          # raise / track a dispute                ← NEW
│   ├── ratings/
│   ├── notifications/
│   └── profile/
└── main.dart
```

Packages unchanged (riverpod, dio, go_router, freezed, firebase_messaging, image_picker, video_player, cached_network_image); add a maps package for discovery and a date/calendar picker for the event-date selector.

---

## 5. Data model (key tables)

Only the fields that matter for the design are shown.

**users** — `id, role_mask (customer|baker|admin), phone, email, phone_verified, created_at`

**baker_profiles** — `user_id, business_name, bio, location (geography point), delivery_radius_km, status (pending|approved|suspended), kyc_status, lead_time_days, daily_order_capacity, created_at`

**baker_blackout_dates** — `baker_id, date` (days the baker can't take orders)

**product_categories** — `id, name, slug`

**products** — `id, baker_id, category_id, title, description, base_price, lead_time_days, active`

**product_images** — `id, product_id, media_id, position`

**orders** — `id, customer_id, baker_id, product_id, status, event_date, delivery_address, delivery_location (point), total_amount, deposit_amount, balance_amount, commission_amount, created_at`

**order_specs** — `id, order_id, key, value` (or a structured JSONB column)

**quotes** — `id, order_id, version, amount, deposit_pct, valid_until, status (proposed|accepted|superseded|expired)`

**message_threads / messages** — `thread(order_id) … message(thread_id, sender_id, body, media_id?, created_at)`

**production_updates** — `id, order_id, stage, progress_pct, notes, created_at`

**media** — `id, order_id?, owner_id, kind (image|video), s3_key, thumb_key, status`

**deliveries** — `id, order_id, method (own|courier), courier_ref?, status, proof_media_id?, dispatched_at, delivered_at, confirmed_at`

**payments** — `id, order_id, kind (deposit|balance|refund), psp_ref, amount, status, idempotency_key`

**ledger_accounts** — `id, kind (customer|baker_pending|baker_available|platform_revenue|refunds), owner_id`

**ledger_entries** — `id, txn_id, account_id, debit, credit, created_at` (each txn's entries sum to zero)

**transactions** — `id, kind, order_id, created_at`

**payouts** — `id, baker_id, amount, psp_ref, status, created_at`

**disputes** — `id, order_id, raised_by, reason, status (open|resolved|rejected), resolution, refund_amount, resolved_by, resolved_at`

**reviews** — `id, order_id, customer_id, baker_id, rating (1–5), body, created_at`

**notifications** — `id, user_id, channel (push|sms|in_app), type, payload, read_at, created_at`

---

## 6. Order state machine

Full state list (the original happy path, plus the exit branches):

```
DRAFT
  → QUOTE_REQUESTED → NEGOTIATING → QUOTED → APPROVED
  → DEPOSIT_PENDING → DEPOSIT_PAID
  → IN_PRODUCTION → READY
  → OUT_FOR_DELIVERY → DELIVERED
  → COMPLETED

branches reachable from the above:
  CANCELLED      (with stage-dependent refund)
  DISPUTED       (freezes funds; resolves to COMPLETED or REFUNDED)
  REFUNDED
```

### Transition table

| From | Event | To | Money effect |
|---|---|---|---|
| DRAFT | customer requests quote | QUOTE_REQUESTED | none |
| QUOTE_REQUESTED ⇄ NEGOTIATING | messages / revised quotes | QUOTED | none |
| QUOTED | customer accepts | APPROVED | none |
| APPROVED | deposit invoice issued | DEPOSIT_PENDING | none |
| DEPOSIT_PENDING | PSP confirms deposit (webhook) | DEPOSIT_PAID | deposit **held** (customer → escrow) |
| DEPOSIT_PAID | baker starts | IN_PRODUCTION | none |
| IN_PRODUCTION | baker marks ready | READY | none |
| READY | baker dispatches | OUT_FOR_DELIVERY | none |
| OUT_FOR_DELIVERY | customer/courier confirms receipt | DELIVERED | balance invoice issued |
| DELIVERED | PSP confirms balance (webhook) | COMPLETED | **release**: baker payout + 5% to platform |
| any pre-COMPLETED | cancel | CANCELLED | per refund matrix (§7) |
| DELIVERED | customer disputes | DISPUTED | funds **frozen** |
| DISPUTED | admin resolves | COMPLETED / REFUNDED | release or refund per ruling |

**Guards worth enforcing in code:**
- Can't reach `APPROVED` unless the baker can fulfill by `event_date` (lead time + capacity + not a blackout date).
- Can't reach `COMPLETED` without a `DELIVERED` confirmation.
- A baker cannot transition their own order to `DELIVERED` without customer or courier proof-of-delivery.

---

## 7. Cancellation & refund matrix

The deposit exists so cancellation isn't free once ingredients are bought. Percentages are sane defaults — make them configurable per baker.

| Stage at cancellation | Who cancels | Customer refund | Baker receives | Platform |
|---|---|---|---|---|
| Before DEPOSIT_PAID | either | n/a (no money moved) | — | — |
| DEPOSIT_PAID, not yet IN_PRODUCTION | customer | deposit minus processing fee | 0 | small fee |
| IN_PRODUCTION | customer | partial (e.g. 0–50% of deposit by stage) | remainder of deposit | commission on what baker keeps |
| Any stage | **baker** (can't fulfill) | **full refund** | 0 | 0 + baker rating/penalty |
| DELIVERED → DISPUTED | customer | admin decides: full / partial / none | inverse of refund | commission on released portion |

**Dispute resolution:** raising a dispute freezes the held funds. An admin reviews the production media, messages, and delivery proof, then rules. Until then, nothing releases.

---

## 8. Payment & escrow flow

```
Customer pays deposit (M-Pesa STK / card)
        │  PSP collects
        ▼
Funds held by PSP (escrow / sub-account)      ← ledger: customer ↓  escrow ↑
        │
   Production → Delivery → customer confirms receipt
        │
Customer pays balance
        │  PSP confirms (webhook)
        ▼
PSP splits & releases                          ← ledger:
   • baker_available ↑  (95%)                     escrow ↓
   • platform_revenue ↑ (5%)                       baker_pending → baker_available
        │
   Payout to baker
```

**Worked example — KES 20,000 order, 50% deposit:**

| Item | Amount |
|---|---|
| Order total | 20,000 |
| Deposit (50%, held first) | 10,000 |
| Balance (after delivery) | 10,000 |
| Platform commission (5% of total) | 1,000 |
| Baker net | 19,000 |

Simplest accounting: take the full 1,000 commission at final release from the gross, rather than splitting it across deposit and balance. Commission is realized only on `COMPLETED` orders — never on cancelled/refunded ones.

---

## 9. API surface (by domain)

```
POST   /auth/register            POST /auth/login
GET    /me                       PATCH /me

# Bakers & onboarding
POST   /bakers                   PATCH /bakers/:id
POST   /bakers/:id/verify        # KYC submission
GET    /bakers/:id/availability  PUT  /bakers/:id/availability

# Discovery
GET    /search/bakers            # filters: category, price, rating, deliver-to (lat/lng)
GET    /search/products

# Catalog
GET    /products                 POST /products
GET    /categories

# Orders, quotes, messaging
POST   /orders                   GET  /orders/:id
POST   /orders/:id/quotes        POST /orders/:id/quotes/:qid/accept
GET    /orders/:id/messages      POST /orders/:id/messages

# Production & media
POST   /orders/:id/production    # stage update
POST   /media/presign            # returns presigned S3 URL

# Delivery
POST   /orders/:id/delivery/dispatch
POST   /orders/:id/delivery/confirm     # proof-of-delivery → gates final payment

# Payments
POST   /orders/:id/payments/deposit
POST   /orders/:id/payments/balance
POST   /payments/webhook                # PSP settlement events (idempotent)

# Disputes & reviews
POST   /orders/:id/disputes             POST /reviews

# Admin
GET    /admin/bakers/pending     POST /admin/bakers/:id/approve
GET    /admin/disputes           POST /admin/disputes/:id/resolve
POST   /admin/orders/:id/refund
```

---

## 10. Realtime events (push to customer)

Quote ready · deposit confirmed · production updated · ready · out for delivery · delivered · review request · **dispute update**. Deliver over WebSocket when the app is open, fall back to FCM push, and use SMS for the money-critical ones (deposit confirmed, balance due, payout sent).

---

## 11. MVP phasing

1. **Auth + roles + baker onboarding/verification + minimal admin panel.**
2. **Bakers, catalog (with categories), discovery/search + geo.**
3. **Orders + versioned quotes + messaging + scheduling/lead-time validation.**
4. **Payments end-to-end via licensed PSP** — deposit hold, split, delayed payout, *plus refunds, cancellation logic, and commission* (same code path).
5. **Production timeline + media (presigned uploads).**
6. **Delivery + proof-of-delivery wired to payout release.**
7. **Ratings, then dispute hardening + analytics.**

This pulls payment correctness and the dispute surface forward (de-risk while small) and treats admin/disputes as a thread through every phase.

---

## 12. Two things to settle before writing much Go

1. **Written confirmation** from your chosen PSP that their split-payment product supports *delayed* release (hold deposit now, release after delivery). The whole escrow model depends on it.
2. **A Kenyan fintech lawyer's sign-off** that routing funds through a licensed PSP keeps *you* out of PSP-licence territory for this specific flow.

Both answers shape the data model more than any framework choice.
