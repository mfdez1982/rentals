# Rentals — Product Overview

*A non-technical description of what the product does. Last reviewed: July 2026.*

This document explains **what** the application does and **why**, in business terms. It does not describe how any of it is built. Two companion documents cover the technical side: `DEVELOPER_ONBOARDING.md` (how the code is organised) and `recollections.md` (the design reasoning behind the bill pass-through feature).

---

## 1. What this product is

Rentals is a web application for **small private landlords** — people who own one to five properties and rent them out themselves, without a management agency.

These landlords typically run their portfolio out of a spreadsheet, a bank statement, and their memory. That works until it doesn't: a rent payment is missed and nobody notices for two months; the utility bill that should have been passed on to the tenant is forgotten; and every year, tax season means reconstructing twelve months of income and deductible expenses from scratch.

The product replaces that with a single place to record properties, tenancies, rent payments, and costs — and then does the arithmetic that landlords otherwise do by hand: what is overdue, what a tenant owes back for a utility bill, and what can be deducted for tax.

It is a **multi-landlord service**. Many landlords use the same application, and each one sees strictly and only their own portfolio. This isolation is the product's central promise; no landlord can ever see another's properties, tenants, or figures.

**What it is not:** it is not a payment processor (no money moves through the system — it records what happened), not a listings or tenant-finding marketplace, and not a property management tool for agencies handling large portfolios.

---

## 2. Who uses it

### The Landlord
The primary user. Signs up, and from that moment owns a portfolio: properties, the tenancies on them, the rent schedule, and the costs. Everything in the product is organised from the landlord's point of view.

### The Tenant
Someone renting one of those properties. A tenant does **not** sign up on their own initiative — they are invited by their landlord, by email, and attached to a specific tenancy. What they get is deliberately narrow: a read-only view of their own rentals, their rent schedule, and any amounts they owe the landlord back. A tenant never sees the property's costs, the landlord's other tenancies, or anything about the rest of the portfolio.

### The same person can be both
This is intentional and matters. Someone can own a flat they rent out *and* rent the flat they live in. One account covers both; the application shows them the right dashboard depending on which role they are acting in, and someone who is only a tenant never sees landlord features at all.

### The Administrator
An internal role for whoever operates the service. Administrators reach a separate back-office area for support and oversight across all accounts. An administrator is not a landlord and has no portfolio of their own.

---

## 3. The core concepts

Seven ideas make up the whole product. Everything else is a view onto them.

**Property** — a single rentable place. It is the top-level thing a landlord owns and the container for everything below. A property's status is never set by hand; the application derives it. A property is "rented" if a tenancy covers today, "available" otherwise, and it is flagged when any rent on it is overdue.

**Rental Agreement** — one tenancy on one property: a start date, an end date, and a monthly rent. A property accumulates agreements over time as tenants come and go. An agreement is upcoming, active, or expired purely according to today's date. When one tenancy ends and another begins, the landlord creates a new agreement rather than editing the old one — so history is preserved.

**Payment** — one expected rent instalment: an amount, a due date, and, once it arrives, the date it was paid. Payments are usually created in bulk when the tenancy starts, generating the whole monthly schedule in one step. A payment with a due date in the past and no payment date is **overdue**, and that status propagates upward so the landlord sees it at the property level without going looking.

**Expense** — a cost attached to a property: tax, insurance, utilities, community fees, repairs and maintenance, management and legal, financing, or other. Expenses feed the tax report. An optional link to the invoice can be stored alongside.

**Tenant Invitation** — the mechanism connecting a real person to a tenancy. The landlord enters an email address; the invitee receives a message and can accept or reject. Only on acceptance does the person become a tenant with access.

**Recollection** — money the landlord paid on the tenant's behalf and expects back, most often a utility bill. This is the product's most distinctive feature and section 5 covers it in full.

**Note** — a free-text reminder with an optional due date. A note can stand alone, or be attached to a property or a tenancy. Notes go overdue like payments do. This is the informal layer: "chase the boiler service", "renewal conversation due in March".

---

## 4. What a landlord does

The typical path through the product, in the order a real user encounters it.

**Sign up.** Registering creates the account and the landlord profile together. There is no setup wizard or configuration step; the landlord lands on an empty portfolio and starts adding.

**Add a property.** Name and address. That is enough to begin.

**Create a rental agreement.** Start date, end date, monthly rent. Two rules are enforced at this point, because a mistake here corrupts everything downstream: the end date must be after the start date, and **two agreements on the same property cannot overlap in time**. A property cannot be rented to two parties at once, and the application refuses to record it. When a tenancy is renewed, the landlord starts from the previous agreement and the new one is pre-filled with the prior dates and rent, so a renewal is a small edit rather than a re-entry.

**Generate the rent schedule.** Rather than entering twelve payments by hand, the landlord gives a start date and a number of months, and the whole schedule is created at once. Individual instalments can then be edited — for a mid-tenancy rent change, say — and are marked paid as the money arrives.

**Invite the tenants.** The landlord enters the tenant's email. If that person already has an account they are notified inside the application; if not, they receive an invitation to create one. **An invitation expires after 14 days** if it is not answered, at which point the landlord can send a fresh one. Both sides are kept informed: the landlord is notified when an invitation is accepted or rejected, and a tenant is notified if they are removed from a tenancy. A tenancy can have several tenants — flatmates or a couple — and this matters for how bills are split.

**Record expenses.** Costs are logged against the property as they occur, each with a category. Some are marked *collectable*, meaning the landlord intends to recover them from tenants — see section 5.

**Pull the tax report.** At year end, the landlord generates a per-property, per-year summary — gross rental income, the deductible portion of each expense, and the ratio used to calculate it — and it is saved as a named, permanent snapshot alongside the property's earlier reports. Section 6 explains the calculation and how saved reports behave.

**Keep notes.** Reminders, general or attached to a specific property or tenancy, marked complete when dealt with.

---

## 5. Passing utility bills on to tenants

This is the feature that most distinguishes the product, and the one whose behaviour is worth understanding precisely, because it involves someone else's money.

### The situation
A landlord's name is on the water or electricity account, so the landlord pays the bill. Contractually, the tenant owes it. The landlord now has to work out who owes what — and that is harder than it looks, because **a bill covers a period of time, and tenancies change within that period.** A tenant may move out halfway through a billing period. The flat may sit empty for a fortnight. A new tenant may move in before the bill arrives.

Splitting that fairly by hand is exactly the kind of arithmetic landlords get wrong or give up on.

### How it works
When logging a bill, the landlord marks it **collectable** and gives the period it covers. The application then compares that period against every tenancy on the property and proposes a split, **charging strictly by days occupied**. The landlord reviews the proposal, chooses which tenants to charge, adjusts amounts if needed, optionally sets a repayment due date, and confirms.

### A worked example
A landlord logs a water bill of **310** covering **1–31 March** (31 days). The property had two tenancies that month:

| Tenancy | Covers | Days in the billing period | Charged |
|---|---|---|---|
| Outgoing tenant | until 10 March | 10 | **100.00** |
| *(vacant)* | 11–20 March | 10 | *absorbed by the landlord* |
| New tenant | from 21 March | 11 | **110.00** |

Each tenancy is charged its own days against the **full** 31-day period — 10/31 and 11/31 of 310. The ten vacant days in the middle are nobody's responsibility but the landlord's, and the application says so rather than quietly redistributing them. This is deliberate: the alternative, splitting the whole bill between whoever happened to be there, would overcharge tenants for days the property was empty.

If a tenancy has two tenants on it, its share is split evenly between them, to the cent, and the landlord can override each amount before confirming.

### The rules that govern it
- **A tenancy can only be charged once per bill.** Re-running the split on the same bill will not create duplicate charges. If a tenancy was not charged the first time, a later run will offer just that one — so the landlord can work incrementally.
- **A charge can be recorded with no tenant attached.** A slice covering a period with no accepted tenant is still recorded as money to collect. From the landlord's perspective, it is an amount owed whether or not a name is attached to it yet.
- **Charges are permanent records, not editable rows.** Once created, a charge is a snapshot of what was agreed. It can be marked paid, marked unpaid again, or deleted outright — but not quietly edited afterwards. For the same reason, a bill or tenancy with charges against it cannot be deleted while they exist.
- **If no tenancy covers the billing period at all**, the application explains that plainly and offers nothing to confirm, rather than producing a meaningless split.

### What the tenant sees
The tenant's rentals view shows an "amounts to repay" section: the bill's description, the period *they personally* were charged for, the amount, the due date, and whether it is still outstanding. They see their own share and nothing else — not the bill's full amount, not what any other tenancy was charged, not the property's costs.

### Why this is not income
**Recollected money is an advance being repaid, not rental income.** The landlord paid 310 and recovers up to 310; nothing is earned. Consequently these amounts are excluded from the tax report entirely — they appear in neither income nor deductions. Treating them as income would inflate the landlord's declared earnings on money that was never theirs. The underlying bill is still recorded as an expense in the normal way.

---

## 6. The tax report

For a chosen property and year, the report gives the landlord what an accountant asks for.

**Gross income** — the total rent due for that property across the year.

**The deductible ratio** — the heart of the calculation. Costs are only deductible for the part of the year the property was actually let. The application counts the days covered by a tenancy during that year and divides by the days in the year. A property let from 1 April to 31 December has 275 rented days out of 365, giving a ratio of **0.7534**.

**Deductible expenses** — every deductible cost recorded against the property that year, listed with its category, its full amount, and its deductible portion after the ratio is applied. A 1,000 insurance premium on the property above contributes 753.40 as deductible. Costs marked *collectable* — utility bills the landlord passes on to tenants, section 5 — are **not** deductible and are left out of the report; the landlord is warned if any such cost is still flagged deductible for the year, so it can be corrected before generating.

**Reports are saved, not just displayed.** The landlord picks a year and generates a report, and the result is **stored as a permanent snapshot** — the figures as they stood at that moment. A property builds up a list of saved reports over time; each can be opened, given a name (e.g. "2025 filed return"), or deleted. A saved report is **frozen**: only its name can be changed afterwards, never its numbers. If an expense or a tenancy date is corrected later, existing reports are unaffected — the landlord generates a fresh one to capture the change. This preserves a record of exactly what was reported for each year rather than silently rewriting history. Any year with activity can be selected.

**A necessary caveat:** this is a calculation aid, not tax advice, and it implements one common pro-rata convention. Deductibility rules vary by jurisdiction and change over time. The report is a starting point for a conversation with an accountant, not a substitute for one.

---

## 7. Rules worth knowing

The constraints with real business consequences, in one place:

- **Tenancies on one property cannot overlap.** Enforced at creation; a property cannot be double-let.
- **An agreement's end date must fall after its start date.**
- **Tenant invitations expire after 14 days** and must be re-sent after that.
- **A tenant only gains access when they accept.** An invited-but-unanswered email address has no visibility.
- **Utility bills are split strictly by days occupied**, and unoccupied days are absorbed by the landlord rather than passed on.
- **Recollected amounts are never treated as rental income**, and collectable costs are excluded from the tax report's deductions.
- **A generated tax report is a frozen snapshot** — its figures are fixed at generation time; only its name can be edited afterwards, and later corrections require generating a new report.
- **Recorded charges are immutable snapshots** — markable as paid or deletable, but not editable after the fact.
- **Status is always derived, never stored.** Rented, available, overdue, active, expired — all calculated from dates each time they are displayed, so they cannot drift out of date or contradict the underlying records.
- **Every landlord's data is isolated.** No cross-account visibility exists in any view.

---

## 8. Plans and access levels

The service is offered on **three tiers** — Free, Pro, and Premium — so a landlord pays in proportion to how much they lean on the product.

- **Free** is deliberately usable, not a crippled demo: a landlord can run a single property end to end — its tenancy, the rent schedule, expenses, tenant invitations, and notes. It is capped at **one property** (enforced — the "Add a Property" action is disabled once a free landlord has one), and the features that turn the product from a ledger into a business tool are held back.
- **Pro** removes the property cap and unlocks the features that save a landlord real money and time — the year-end **tax report** and **utility-bill pass-through (recollections)** in particular. This is the tier aimed at the typical active landlord.
- **Premium** is the top tier for landlords who outgrow Pro: everything Pro has, with room for higher-end capabilities as they are added.

The reasoning behind the split: most landlords in the product's audience own a single property, so a property cap alone would never prompt them to pay. The features reserved for paid tiers — the money-related ones a landlord feels the pain of doing by hand — are what make a paid plan worth it for that majority, while the property cap captures the minority who grow a larger portfolio.

**How a plan is assigned today.** Each landlord is recorded on a tier, and for now that tier is set by an administrator from the back office — there is no self-service checkout yet (see section 10). A landlord's current tier is shown beside their name once signed in. The machinery that maps a tier to the features it unlocks is in place; the property cap is the first individual feature lock enforced, and the rest are being rolled out tier by tier.

---

## 9. Supporting details

**Languages.** The application is fully available in English and Spanish, switchable at any time.

**Email.** Tenant invitations and password resets are sent by email. *Production email delivery is not yet configured* — see section 10.

**Privacy.** A cookie consent banner with granular preferences is presented on first visit. Landlords can edit their account details and delete their account outright.

**Access on sign-in.** Users land on the view that matches who they are: administrators in the back office, tenants-only in their rentals, landlords on their property dashboard.

---

## 10. What the product does not do yet

Stated plainly, so expectations are set correctly.

- **No production email delivery.** Invitations and password resets are generated but not yet configured to send from a live environment. This blocks real-world use of the tenant invitation flow.
- **No self-service billing.** The plan tiers exist and can be assigned by an administrator (see section 8), but there is no payment mechanism for the service itself, no self-service upgrade or checkout, and no trial handling — despite pricing being shown on the public landing page. The property cap is enforced; the tax-report and recollections locks are still being rolled out, so tier differences are not yet fully enforced across the board.
- **No payment processing.** Rent and repayments are *recorded* as having happened; no money moves through the application. Landlords reconcile against their own bank account.
- **No document storage.** File uploads are technically available but unused — leases, invoices, and receipts cannot be attached. Expenses hold a link to an invoice hosted elsewhere, nothing more.
- **No multi-unit properties.** Each property is a single rentable place. A building with several independently-let flats must be entered as several properties, and cannot be reported on as one building.
- **No automated reminders.** Overdue rent and outstanding repayments are visible when the landlord looks, but nothing is sent to chase them.
- **No reporting across the portfolio.** The tax report covers one property for one year; there is no consolidated view over all properties.
- **No bank or accounting integrations**, and no export to accounting software.
