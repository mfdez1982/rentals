# Recollections — Design & Rationale

*Status: implemented (v1) — July 2026*

## Problem

Landlords sometimes pay utility bills for a property themselves and then collect the money back from tenants. Two structural mismatches make this non-trivial:

1. **Expenses hang off `Property`; tenants hang off `RentalAgreement`** (via `AgreementTenant`). A bill must be bridged across that gap.
2. **Utility bills cover a period of time.** A bill's period can straddle multiple agreements (tenant turnover mid-bill), cover days with no tenancy at all, or be partially covered by an agreement that starts/ends inside it. The amount must be prorated.

## Core concept

A **`Recollection`** is a flat row: money the landlord advanced that someone must pay back.

```
Recollection
  expense_id            (the source bill)                 not null
  rental_agreement_id   (the tenancy slice it belongs to) not null
  agreement_tenant_id   (the payer)                       NULLABLE
  amount                landlord-editable at creation
  period_start/end      the computed overlap slice — immutable, not editable
  due_date              optional
  status                pending | paid
  paid_date
```

Key stance: **a recollection exists independent of any tenant.** From the landlord's point of view it is simply "money to collect", whether or not a person is attached. The tenant link is an enrichment whose purpose is tenant-side awareness (`my_rentals` shows "amounts to repay").

## Decisions and why

### Flat model, not nested shares
One row per payer (charging 2 tenants for one slice = 2 rows), rather than a per-agreement recollection with child "share" rows. Paid/overdue state lives naturally on each row; the "grouped by agreement" view is a UI concern only. This follows directly from "tenant or no tenant, it's the same thing — something to collect".

### Proration is independent per agreement
```
slice_amount = expense.amount × overlap_days(agreement, expense) / expense.period_days
```
Each agreement's share is computed against the **full** expense period, never against the covered portion. Consequences, all deliberate:

- Days covered by no agreement are simply never claimed — the landlord absorbs them. That's a feature (there was nobody to charge).
- Adding an agreement later (e.g. a new tenancy that picks up the tail of an old bill) computes its own slice **without disturbing existing slices** — including already-paid ones. Composability is the whole point.
- No global "slices must sum to the bill" constraint exists, because uncovered days are expected. Rounding is per-slice to cents.

Day counts are inclusive (`Mar 1–Mar 31` = 31 days; `period_days` on `Expense`, overlap in `RecollectionGenerator`).

### Idempotent, incremental "Recollect" action
"Recollect" is not a one-shot event. Re-running it on the same expense proposes/creates rows **only for `(expense, agreement)` pairs that don't exist yet** and never touches existing rows. Backed at the DB level by a unique index on `(expense_id, rental_agreement_id, agreement_tenant_id)` plus a partial unique index on `(expense_id, rental_agreement_id) WHERE agreement_tenant_id IS NULL` (unique indexes treat NULLs as distinct, so the no-payer row needs its own guard).

v1 relies on the landlord remembering to re-run Recollect after adding a new agreement. Proactive detection is deferred (see below).

### The two zeros (validation rule)
- **An overlapping agreement with no accepted tenants** → fine. One recollection with `agreement_tenant: nil`. The tenancy exists; the person just isn't in the app.
- **No agreement overlaps the expense period at all** → hard error, nothing created. There is no tenancy slice to anchor the money to; recording it would invent a debtor. The UI tells the landlord to add/adjust an agreement first.

### `Expense.collectable` flag
An expense is marked `collectable` in its form. The flag's job: it gates the service-period fields (`period_start`/`period_end`, **mandatory when collectable** — proration is impossible without them) and gates the "Recollect" action. It also serves as the intent signal for future proactive detection.

### Landlord decides, system assists
The Recollect page shows the computed slices (agreement, overlap window, prorated amount — display-only) and, per slice, the accepted tenants as checkboxes (default: all checked) with editable amounts (default: equal split, largest-remainder cent rounding so shares sum exactly to the slice). The landlord can uncheck tenants or override amounts freely — there is **no constraint that share amounts sum to the slice**. Unchecking every tenant degrades to a single no-payer recollection for the full slice: consistent with "0 tenants is still money to collect".

### Immutability / regeneration semantics
Recollections are snapshots. The system never silently rewrites one — especially not a paid one. Editing the underlying expense does not cascade. Pending recollections can be deleted by the landlord (and re-generated); deleting an `Expense` or `RentalAgreement` that has recollections is blocked (`dependent: :restrict_with_error`). Destroying an `AgreementTenant` nullifies the payer on its recollections (the debt survives as no-payer); setting it to `removed` keeps them visible to that user — the debt was already theirs.

### Not income — no tax report interaction
Recollected money is **advanced funds being reimbursed**, not income (a balance-sheet item, not P&L). The expense remains 100% deductible; recollections never feed the Tax Report's gross income. Do not "fix" this later by adding paid recollections to income.

### Due date & reminders
`due_date` is optional. When set and passed while pending, the recollection is `overdue?` (same pattern as `Payment`). v1 surfaces this as in-app badges only; **email reminders are deferred** — they need a scheduled/background job runner the stack doesn't have yet.

## Implementation map

| Piece | Where |
|---|---|
| Model | `app/models/recollection.rb` (+ `collectable`/period validations in `expense.rb`) |
| Proration + creation | `app/services/recollection_generator.rb` (`#preview`, `#generate!`, `#no_overlapping_agreements?`) |
| Landlord flow | `RecollectionsController` (`new`/`create` nested under property→expense; `mark_paid`/`destroy` under property), `app/views/recollections/` |
| Property show | Recollections list section (own turbo frame) below the expenses table; loaded via `PropertyShowLoadable` |
| Expense form | `collectable` checkbox toggles period fields (`toggle` Stimulus controller) |
| Tenant surface | `my_rentals#show` "Amounts to repay" (scoped strictly via `agreement_tenants.user_id = current_user.id`; no-payer and other tenants' rows never shown); pending-count badge on `my_rentals#index` |
| Tests | `spec/models/recollection_spec.rb`, `spec/services/recollection_generator_spec.rb`, `spec/requests/recollections_spec.rb`, extensions to expense/my_rentals specs |

## Deferred (phase 2 candidates)

- **Proactive detection**: when an agreement is created/extended over a period covered by a collectable expense, nudge the landlord to recollect the new slice (landlord confirms; never auto-create). The `collectable` flag + existing recollections give the signal.
- **Email reminders** for due/overdue recollections (needs a job runner).
- **Stale-recollection handling** when an agreement is shortened after recollections exist: flag for the landlord to void/adjust; never rewrite silently.
