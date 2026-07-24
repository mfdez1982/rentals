# Developer Onboarding Guide

A practical guide for developers joining the **Rentals SaaS** project. It assumes you know Ruby on Rails; it does *not* assume you know this codebase. Read it end-to-end once, then keep it open as a reference for your first week.

> This guide reflects the code as it actually is. Some features here (tenant invitations, notes, tenant-facing dashboards, the admin backoffice) were listed as "future direction" in `CLAUDE.md` but are now built — trust the source files and this guide over the older aspirational notes.

---

## 1. Overview

Rentals SaaS is a **multi-landlord** app for small landlords (1–5 properties each) to manage their rental portfolios. Each landlord signs up, logs in, and sees **only their own data** — multi-tenancy is the single most important invariant in the codebase (see §3).

The domain is a straightforward ownership chain:

```
User (auth record, Devise + role enum: landlord | admin)
  └─ Landlord (profile, auto-created for landlord-role users; plan enum: free | pro | premium)
       └─ Property
            ├─ RentalAgreement
            │     ├─ Payment
            │     └─ AgreementTenant ──▶ User (a tenant)
            ├─ Expense              (direct on Property; deductible ones feed the tax report)
            └─ TaxReport            (persisted, immutable snapshot per property/year)
  └─ Note (belongs_to landlord; optional polymorphic noteable: Property or RentalAgreement)
```

A `User` is the authentication identity. A `Landlord` is a separate profile model created automatically on sign-up **only for landlord-role users** (`after_create :create_landlord, if: :landlord?` in `app/models/user.rb`). Admins never get a `Landlord`.

Crucially, **the same `User` can be both a landlord and a tenant.** A landlord invites tenants to a rental agreement by email; when an invited person accepts, an `AgreementTenant` row links their `User` to the `RentalAgreement`. `User#tenant?` is true when they have any accepted invitation. This is why the root path routes people to different dashboards depending on who they are (see §4).

**Tech stack:** Rails 8, PostgreSQL, Devise (auth), Hotwire (Turbo Frames + Stimulus), ERB views (no React/TS), Tailwind + DaisyUI 5 via CDN (`emerald` theme), ActiveStorage (present, barely used), RSpec + FactoryBot (Ruby tests), Playwright (browser E2E). Full EN/ES i18n.

---

## 2. Local Setup

This project runs in a **devcontainer**. You cannot install system packages or gems from inside it — if something is missing, tell the host maintainer. All the commands below are run by you (or the host) from the devcontainer shell.

```bash
# 1. Create and migrate the database
bin/rails db:create db:migrate

# 2. Seed development data (dev landlord, three plan demo users, and sample records)
bin/rails db:seed

# 3. Start the server
bin/rails s          # http://localhost:3000
```

In **development**, `current_landlord` auto-signs-in `dev@example.com` if that user exists (see `ApplicationController`), so you can browse without logging in every time. Make sure the seed creates that user.

**Running the two test suites:**

```bash
bin/rspec                       # Ruby unit / controller / request / service specs
npm test                        # Playwright E2E (needs the Rails server running)
```

Playwright is configured in `playwright.config.js`: tests live in `tests/e2e`, run **sequentially** (`workers: 1`, `fullyParallel: false`) against `http://localhost:3000`, and produce an HTML report. Open `playwright-report/index.html` in a browser to inspect failures, traces, and screenshots.

> **Important:** Playwright drives a *real* running server. Start `bin/rails s` first (development mode is fine), then run `npm test` in a second shell.

---

## 3. Architecture & Multi-Tenancy

### The golden rule

**Every query must be scoped to `current_landlord`, starting from `current_landlord` and walking down the association chain.** Never trust the view or the URL to enforce ownership — an attacker can hand-craft any ID.

`current_landlord` is defined in `ApplicationController`:

```ruby
def current_landlord
  @current_landlord ||= current_user&.landlord
end
helper_method :current_landlord
```

Always load records *through* it, so a landlord physically cannot reach another landlord's rows:

```ruby
@property  = current_landlord.properties.find(params[:property_id])
@agreement = @property.rental_agreements.find(params[:rental_agreement_id])
@payment   = @agreement.payments.find(params[:id])
```

`current_landlord.properties.find(id)` raises `RecordNotFound` (→ 404) for a property that isn't theirs — that's the enforcement. If you ever find yourself writing `Property.find(...)` or `Payment.find(...)` in a controller, stop: that's a tenancy leak.

`PropertiesController#set_property` is the canonical pattern:

```ruby
def set_property
  @property = current_landlord.properties.find(params[:id])
end
```

### Derived state (never stored as columns)

The domain leans heavily on computed methods rather than status columns. Know these — they show up everywhere:

| Method | Where | Meaning |
|---|---|---|
| `property.rented?` | `Property` | any agreement is active today |
| `property.active_rental_agreement` | `Property` | the currently-active agreement, or nil |
| `property.next_unpaid_payment` | `Property` | soonest payment with no `paid_date` |
| `property.has_overdue_payments?` | `Property` | any agreement has an overdue payment |
| `agreement.active? / upcoming? / expired?` | `RentalAgreement` | date-window state relative to today |
| `agreement.has_overdue_payments?` | `RentalAgreement` | any payment overdue |
| `payment.overdue?` | `Payment` | unpaid *and* `due_date < today` |
| `note.overdue?` | `Note` | active, has `due_date`, and it's past |

`RentalAgreement` also enforces two custom validations you'll trip over: `end_date` must be after `start_date`, and agreements for the same property **may not overlap in time** (`no_overlapping_agreements`).

### Roles and routing at the root

The root path (`/`) is smart about who you are (`redirect_root_appropriately` in `ApplicationController`):

- **Admin** → `backoffice_root_path` (the `Backoffice::` namespace, guarded by an `admin_constraint` lambda in `routes.rb`).
- **Tenant-only** (a user with accepted invitations but no properties of their own) → `my_rentals_path`.
- **Everyone else** (landlords) → the property dashboard, rendered at root directly.

`after_sign_in_path_for` uses the same logic via `home_path_for`.

### Services

Non-trivial logic lives in plain Ruby service objects under `app/services/`:

- **`TaxReportGenerator`** — given a property + year, computes the pro-rata deductible ratio (active rental days ÷ days in year), gross income (sum of payments due that year), and a per-expense deductible breakdown. `#generate` returns the figures as a hash; `#create_report!` persists them as an immutable `TaxReport` snapshot (the per-expense breakdown is frozen into the `expense_lines` JSON column). Only **deductible** expenses are included — collectable (pass-through) expenses are excluded.
- **`TenantInviter`** — creates or reactivates a pending `AgreementTenant` for an agreement + email, and sends the right email depending on whether the invitee is already a registered `User`. Returns a `Result` struct with an `outcome` (`:invited`, `:already_pending`, `:already_accepted`).
- **`RecollectionGenerator`** — given a collectable `Expense`, prorates its amount across every `RentalAgreement` overlapping the expense's `period_start`/`period_end`, independently per agreement, by inclusive days against the *full* expense period (uncovered days are absorbed by the landlord, not redistributed). The landlord then picks payers per slice. Business rationale and worked examples: `docs/recollections.md`.

### Recollections and Notes (model shape)

A `Recollection` (`belongs_to :expense, :rental_agreement`, optional `:agreement_tenant` payer; `status` enum `pending/paid`; optional `due_date`) is a flat row — one per payer, or one with a nil payer when no tenant is charged. Generation is idempotent per `(expense, agreement)` pair (DB-unique-indexed); rows are immutable snapshots, so `Expense`/`RentalAgreement` destroy is `restrict_with_error`'d while any exist. Recollections are excluded entirely from `TaxReportGenerator` — advanced funds, not income.

`Note belongs_to :landlord` with an *optional* polymorphic `noteable` (a `Property`, a `RentalAgreement`, or nil for a general note). `status` enum `active/completed`.

### Plans & feature entitlements (Flipper)

Each `Landlord` carries a **plan** (`enum plan: { free, pro, premium }`, default `free`) — the single source of truth for the subscription tier. Feature access is expressed with **Flipper** (`flipper` + `flipper-active_record`, DB-backed). `Landlord` implements `flipper_id`, so it works as a Flipper actor directly:

```ruby
Flipper.enabled?(:tax_report, current_landlord)
```

`config/initializers/flipper.rb` configures the ActiveRecord adapter and registers two **actor groups** keyed off the landlord's plan — `pro_and_up` (Pro or Premium) and `premium_only`. A feature is granted to a tier by enabling it for the matching group, so changing what a tier includes is a group toggle (in the initializer or the Flipper UI), **not** scattered `if landlord.pro?` checks at call sites. The tier badge beside the signed-in email is driven by `current_landlord.plan` (translated via the `plans.*` i18n keys); admins and tenant-only users have no `Landlord`, so no badge.

Plans are assigned from the back office — `plan` is an editable `Field::Select` on the Administrate `LandlordDashboard`.

**Status:** the enum, Flipper wiring, and admin assignment are in place. Two per-tier locks are live:

- `multi_property` (`pro_and_up`) caps free landlords at one property. `Landlord#property_limit_reached?` blocks a second property in `PropertiesController#create`; the "Add a Property" button is disabled with an upgrade hint on the index for the same case. **Downgrade handling:** `Landlord#active_property` (oldest by `created_at`) stays usable; `Landlord#property_locked?(property)` is true for the rest. Locked properties still list (badge + hint, no delete icon), but `PropertiesController#show`/`#destroy` and the shared `ApplicationController#set_property` (used by every property-nested controller — agreements, payments, expenses, recollections, tax reports, invitations) redirect to the index for them.
- `tax_report` (`pro_and_up`) gates generating, viewing, editing, and deleting reports — `TaxReportsController#{create,show,edit,update,destroy}` via `Landlord#tax_report_allowed?`. The index itself always lists saved reports; a locked landlord sees a prominent `alert-info` upgrade banner there and the Open/Edit/Delete controls per row are hidden, not just disabled.
- `notes` (`pro_and_up`) gates creating, editing, completing, and deleting notes — `NotesController#{create,edit,update,mark_complete,destroy}` via `Landlord#notes_allowed?`. Existing notes stay listed (property tab, agreement tab, and the standalone Notes page); a locked landlord sees the same `alert-info` banner, the "Add Note" button disabled, and per-row action icons hidden.

Recollections locking is still to come. The seed creates one landlord per tier — `free@example.com`, `pro@example.com`, `premium@example.com` (password `password`) — each with its own properties, agreements, payments, expenses, and notes.

---

## 4. Key Workflows

### A. Create a property, then a rental agreement

1. Landlord lands on `PropertiesController#index` (the dashboard). "Add property" opens a modal; submit hits `#create`, scoped via `current_landlord.properties.build(...)`.
2. Clicking a property → `PropertiesController#show`, which calls `load_property_show_data` (from the `PropertyShowLoadable` concern) to build every ivar the tabbed show page needs (agreements, expenses, notes, plus `build`-ed blanks for the new-record forms).
3. On the **Agreements** tab, "Add agreement" posts to `RentalAgreements#create`, nested under the property. The overlap and date-order validations run here.
4. **Renew-with-prefill:** renewing an agreement copies the prior `start_date` + `rent_amount` into the new form so the landlord only tweaks dates.

### B. Track and generate payments

Payments belong to a `RentalAgreement`. Beyond single edits, there's **recurring generation**: `POST rental_agreements/:id/payments/create_recurring` takes a start date + number of months and bulk-creates monthly `Payment` rows. Overdue status is derived (`payment.overdue?`), never stored — so it's always correct without a background job.

### C. Invite a tenant to an agreement

1. On an agreement's show page, the landlord enters a tenant's email → `AgreementTenantsController#create` → `TenantInviter`.
2. `TenantInviter` creates a `pending` `AgreementTenant` with a `has_secure_token` invitation token and emails the person (different template for existing vs. new users). Invitations expire after `AgreementTenant::INVITE_TTL` (14 days).
3. The invitee accepts/rejects via `tenant_invitations` routes. On accept, the row flips to `accepted` and links their `user_id`; they now see the rental under `my_rentals`.
4. **Acknowledgement bookkeeping:** `ApplicationController` exposes `pending_tenant_invitations`, `tenant_removal_notices`, and `landlord_tenant_notifications` as helper methods that drive notification badges — landlords get notified when tenants respond, tenants get notified when removed.

### D. Generate a tax report

On a property's **Tax Report** tab, the frame lazy-loads `TaxReportsController#index` (nested under the property — see §5). There the landlord picks a year and clicks **Generate**, which posts to `#create` and calls `TaxReportGenerator#create_report!` to persist an immutable snapshot. The index lists all saved reports; "Open" navigates (breaking out to `_top`) to `#show`. Reports can be renamed (a modal editing only the `name` — the computed figures are read-only) or deleted. If the year contains **collectable** expenses that are still marked deductible, the index shows a warning listing them so the landlord can fix them before generating (collectable pass-through costs shouldn't be deducted).

---

## 5. Frontend Patterns

No React, no TypeScript. The interactivity is **Hotwire**: Turbo Frames for server-rendered in-place swaps, plus a handful of small Stimulus controllers (auto-discovered via `eagerLoadControllersFrom` in `app/javascript/controllers/index.js`).

### Tabs (client-side, no round trip)

Show pages use a `tabs` Stimulus controller. **All tabs' content is in the DOM at once** — the controller just toggles panel visibility and the active-link class. The one exception is the lazy tax-report frame below.

```erb
<div data-controller="tabs" data-tabs-active-tab-value="agreements">
  <a data-tabs-tab="agreements" data-action="click->tabs#selectTab">Agreements</a>
  <section data-tab-section="agreements"> ... </section>
</div>
```

### Section frames + validation re-render (the important one)

Each tab wraps its table + form in **one Turbo Frame per resource**, named with `dom_id(@property, :agreements)`, `dom_id(@property, :expenses)`, etc. Because the create/edit form lives *inside* that frame, a normal Turbo submit replaces only that frame — success or failure.

The subtle part: on **validation failure**, controllers do **not** render their own template. They render the *parent show template* so Turbo can extract the same section frame, now with errors in place:

```ruby
# PropertiesController#update, on failure of an inline edit
load_property_show_data          # rebuild every ivar show.html.erb needs
@editing_property = @property
render template: "properties/show", status: :unprocessable_entity
```

This is why `PropertyShowLoadable#load_property_show_data` and `AgreementShowLoadable#load_agreement_show_data` exist: any controller (expenses, agreements, payments, notes) that can fail-render one of these pages must first rebuild **all** the ivars that page's ERB references. If you add an ivar to a show page, add it to the matching loadable concern too, or fail-renders will crash.

### Modal editing

Add/edit UI lives in DaisyUI `<dialog>` modals via the shared `shared/_modal` layout, controlled by the single `modal` Stimulus controller:

- Plain "Add X" button: `data-action="click->modal#open"` — just opens the dialog.
- Edit link: `data: { turbo_frame: "<name>_edit_frame", action: "click->modal#openFrame" }` — opens the dialog **and** lets Turbo load the edit form into a named frame (`property_edit_frame`, `expense_edit_frame`, `payment_edit_frame`, `agreement_edit_frame`, `note_edit_frame`).
- `dialogTargetConnected` re-fires whenever a Turbo swap reconnects a `<dialog>`. If the freshly-rendered dialog contains a `[role="alert"]` (validation errors), it reopens itself; a clean success re-render stays closed. It deliberately does *not* fire for the edit-form GET, so opening a form is never mistaken for a submit result.
- Cancel buttons: `data-action="modal#close"`.

### Edit pages as fallback

`*/edit.html.erb` views are thin wrappers: `render layout: "shared/frame_page", locals: { frame_id: "<name>_edit_frame" }` around the same `_edit_modal_content` partial the modal uses. So the same edit view works both loaded into a modal via Turbo **and** as a full-page direct visit. Controllers guard frame-only actions with `redirect_unless_turbo_frame_request(fallback_path)` so a bookmark/refresh of a fragment bounces to the full page instead of rendering a broken partial.

### Lazy frame (tax report)

```erb
<%= turbo_frame_tag dom_id(@property, :tax_report),
      src: property_tax_reports_path(@property), loading: :lazy %>
```

This is the only tab whose content is fetched on demand rather than pre-rendered — it loads `TaxReportsController#index` (the generate control + saved-reports list) into the frame.

---

## 6. Testing

Two suites, two purposes.

### RSpec (`bin/rspec`) — the unit/controller/request layer

Structure under `spec/`: `models/`, `controllers/`, `requests/`, `services/`, `helpers/`, `mailers/`, and `factories/`. Config in `spec/rails_helper.rb` uses transactional fixtures, FactoryBot syntax methods, and Devise integration helpers for request specs.

**Conventions (from `CLAUDE.md`):**
- RSpec, **never** Minitest.
- FactoryBot for fixtures (no fixture YAML for domain records).
- Test **models and controllers**; skip view specs.
- **At minimum, a smoke test for every new controller action.**

Factories live in `spec/factories/`. They chain associations so you can build a full ownership tree cheaply:

```ruby
# spec/factories/rental_agreements.rb
factory :rental_agreement do
  association :property
  start_date { Date.new(2025, 6, 1) }
  end_date   { Date.new(2026, 5, 31) }
  rent_amount { 80.00 }
end
```

When testing multi-tenancy (and you should, for any controller that loads records), the key assertion is: **a landlord requesting another landlord's record gets a 404**, not the record.

### Playwright (`npm test`) — browser E2E

Specs in `tests/e2e/` cover the real user flows: `auth`, `properties`, `rental_agreements`, `payments`, `expenses`, `tax_report`, `multi_tenancy`, `i18n`, `landing`, `error_pages`. They run sequentially against a live `bin/rails s` (Rails dev mode serializes requests behind the reloader lock, so parallel workers cause spurious timeouts — hence `workers: 1`). Reports land in `playwright-report/index.html` with traces/screenshots retained on failure.

You can also drive the running app manually with Playwright against `http://localhost:3000` when debugging a UI issue.

---

## 7. Common Tasks

### Add a user-facing string (i18n is mandatory)

**No hardcoded user-facing text, anywhere.** Views use `t("key.path")`, models use `I18n.t(...)`, controllers use `t(...)` for flash messages. Every new string goes in **both** `config/locales/en.yml` and `config/locales/es.yml`, following Rails' nested convention. Enum display values, validation messages, button labels, placeholders — all translated. Even `"Save"` / `"Cancel"` / `"Delete"`.

### Add a controller action

1. Add the route (keep it nested to preserve scoping — e.g. under `resources :properties`).
2. Scope every lookup from `current_landlord` (§3).
3. If it can render a section-framed show page on validation failure, call the matching `*ShowLoadable` concern first.
4. Translate any flash/alert strings.
5. Write at least a smoke request/controller spec for it.

### Add a model

Standard Rails: generate the migration (the **user** runs `bin/rails g` / `db:migrate` — you only write files). Add DB-level constraints for anything important: foreign keys, `null: false`, unique indexes (look at `db/schema.rb` — nearly every column is constrained, and `agreement_tenants` even has a partial unique index `where: "status IN (0,1)"`). Use `enum` for status fields. Add a factory. If the model is landlord-owned, wire the association so it's reachable *through* `current_landlord`.

### Debug a multi-tenancy bug

Symptom: a landlord can see or edit data that isn't theirs. Trace the controller action and check that **every** `find` starts from `current_landlord` and walks the association chain — a single bare `Model.find(params[:id])` is almost always the culprit. Add a request spec asserting a cross-landlord request 404s.

### Work in this repo (process notes)

- **Present a plan and get approval before writing code** — that's a hard project rule.
- **You (Claude) never run Rails commands** — no `bin/rails`, `bin/rspec`, generators, migrations, or seeds. Write/edit files and ask the user to run them.
- **Never install packages** (`apt-get`/`gem install`/`brew`) — it's a devcontainer; state what's needed and the host installs it.
- **Never commit to git without explicit permission.**

---

## Quick reference

| Need | Where |
|---|---|
| Schema | `db/schema.rb` |
| Models & derived methods | `app/models/` |
| Routes | `config/routes.rb` |
| Tenancy helper | `ApplicationController#current_landlord` |
| Show-page ivar rebuilders | `app/controllers/concerns/*_show_loadable.rb` |
| Services | `app/services/` (`TaxReportGenerator`, `TenantInviter`) |
| Plan entitlements | `Landlord#plan` + `config/initializers/flipper.rb` |
| Stimulus controllers | `app/javascript/controllers/` |
| Translations | `config/locales/{en,es}.yml` |
| Ruby tests | `spec/` — run `bin/rspec` |
| Browser tests | `tests/e2e/` — run `npm test` |
| Project conventions | `CLAUDE.md` |
