# Rentals SaaS — Project Context for Claude Code

## What this project is
A multi-landlord SaaS app for personal rental property management. Small landlords (1–5 properties each) sign up, log in, and manage their own properties. Each landlord sees only their own data.

## Tech stack
- Ruby on Rails 8, PostgreSQL
- Devise for authentication (User model; Landlord is a separate profile model)
- ERB views — no React, no TypeScript
- Hotwire: Turbo Frames for in-place updates, Stimulus for light JS
- Stimulus controllers auto-discovered via `eagerLoadControllersFrom` in `app/javascript/controllers/index.js`
- Tailwind CSS + DaisyUI 5 via CDN (theme: `emerald`)
- ActiveStorage for file uploads (not yet used)
- RSpec + FactoryBot for testing

## Reading the current code
Schema, models, routes, controllers, and view structure are all readable from the source files themselves — do not keep a copy here, it only goes stale. When you need them:
- Schema → `db/schema.rb`
- Models and their methods → `app/models/`
- Routes → `config/routes.rb`
- Controllers → `app/controllers/`
- Views → `app/views/`

## Domain model (the shape, not the fields)
`User` is the auth record (Devise + a `role` enum, default `:landlord`). `Landlord` is a separate profile model belonging to a `User`, created automatically on sign-up **only for landlord-role users** (`after_create :create_landlord, if: :landlord?`). Admins never get a Landlord. A `Landlord` has many `Property` records; a `Property` has many `RentalAgreement` records; a `RentalAgreement` has many `Payment` records. A `Property` also has many `Expense` records directly (not nested under an agreement) — used for the per-property, per-year Tax Report.

**Tenants (the same `User` can be a landlord *and* a tenant).** A landlord invites tenants to a `RentalAgreement` by email. Each invite is an `AgreementTenant` (`belongs_to :rental_agreement, :user` — `user` optional until accepted; `status` enum `pending/accepted/rejected/removed`; `has_secure_token :invitation_token`; 14-day `INVITE_TTL`). When accepted, it links the invitee's `User` to the agreement (`RentalAgreement#tenants` is `agreement_tenants` with `status: accepted`, through `user`). `User#tenant?` is true once they have any accepted invitation. Invites are created/reactivated by the `TenantInviter` service.

**Recollections (utility bill pass-through).** An `Expense` can be marked `collectable` (then `period_start`/`period_end` are mandatory). The landlord runs "Recollect": `RecollectionGenerator` prorates the amount across agreements overlapping the period (independently per agreement, inclusive days, against the full expense period — uncovered days are absorbed by the landlord) and the landlord picks payers per slice. A `Recollection` (`belongs_to :expense, :rental_agreement`, optional `:agreement_tenant` payer; `status` enum `pending/paid`; optional `due_date`) is a flat row: one per payer, or one with nil payer when no tenant is charged. Generation is idempotent per `(expense, agreement)` pair (DB-unique-indexed); rows are immutable snapshots — expense/agreement destroy is restricted while they exist. Recollections are advanced funds, NOT income — zero Tax Report interaction. Design rationale: `docs/recollections.md`.

**Notes.** `Note belongs_to :landlord` and has an *optional* polymorphic `noteable` (a `Property` or a `RentalAgreement`, or nil for a general note). `status` enum `active/completed`; an `active` note with a past `due_date` is `overdue?`.

Derived state (never stored as a column):
- `property.rented?` — true if any agreement is active today
- `property.active_rental_agreement` / `property.next_unpaid_payment`
- `property.has_overdue_payments?` — any agreement has overdue payments
- `rental_agreement.active?` / `upcoming?` / `expired?` — date-window state vs. today
- `rental_agreement.has_overdue_payments?` — any payment is overdue
- `payment.overdue?` — true when `paid_date` is nil and `due_date < Date.today`
- `note.overdue?` — active note whose `due_date` is past
- `recollection.overdue?` — pending with a past `due_date` (due date is optional)
- `user.tenant?` — has at least one accepted `AgreementTenant`

`RentalAgreement` also validates `end_date` after `start_date` **and** rejects agreements that overlap another for the same property.

## Implemented features
- Property management with derived rented/available status
- Rental agreements per property, with renew-with-prefill (start date + rent copied from the prior agreement)
- Payments per agreement, including bulk/recurring generation (start date + number of months) and overdue tracking
- Deductible expenses per property, categorized (`Expense.category` enum)
- Recollections: prorated pass-through of collectable expenses to tenants (landlord Recollect flow with per-tenant splits, mark-paid/delete; tenant "amounts to repay" in my_rentals) — see `docs/recollections.md`
- Tax report per property/year: pro-rata deductible ratio based on active rental days, gross income, deductible expense breakdown
- Tenant invitations: invite by email (`TenantInviter`), accept/reject/dismiss flow, expiry, and landlord/tenant notification badges (see `ApplicationController` helper methods `pending_tenant_invitations`, `tenant_removal_notices`, `landlord_tenant_notifications`)
- Tenant-facing dashboard: `my_rentals` (index/show) for users who are tenants
- Notes: general or attached to a property/agreement, active/completed status, overdue tracking, `mark_complete`
- Admin backoffice: `Backoffice::` namespace (expenses, landlords, payments, properties, rental_agreements, users), guarded by an `admin_constraint` lambda in `routes.rb`
- Devise auth (sign up/in/out, account edit, account deletion, password reset). Emailing is enabled: dev writes to `tmp/mails` (`delivery_method: :file`), test uses `:test`. No production SMTP is configured yet.
- Role-based root routing (`redirect_root_appropriately`): admins → backoffice, tenant-only users → my_rentals, landlords → property dashboard
- EN/ES i18n throughout
- Cookie consent banner with granular preferences

## Multi-tenancy (critical)
Every query must be scoped to `current_landlord`. Never rely on the view alone. Always scope from `current_landlord` down the full chain:
```ruby
@property  = current_landlord.properties.find(params[:property_id])
@agreement = @property.rental_agreements.find(params[:rental_agreement_id])
@payment   = @agreement.payments.find(params[:id])
```
`current_landlord` is defined in `ApplicationController` as `current_user&.landlord`. In development, it auto-signs-in `dev@example.com` if that user exists.

**Tenant-facing access is separate.** Tenants don't own a `Landlord`, so they reach their data through their accepted `AgreementTenant` rows, not `current_landlord` — scope those queries from `current_user` (e.g. `current_user.tenant_rental_agreements`). Don't leak a landlord's full agreement/property data into a tenant view; expose only what the tenancy grants.

## Turbo Frame patterns
These are non-obvious and hard to reconstruct from the code alone — read this before touching any show page or modal-editing flow.

### Modal editing (current pattern, replaces old row inline-edit)
All add/edit UI now lives in DaisyUI `<dialog>` modals rendered by the shared `shared/_modal` layout (`render layout: "shared/modal", locals: { title:, box_class: }`), controlled by the single `modal` Stimulus controller (`app/javascript/controllers/modal_controller.js`):
- `data-controller="modal"` on a wrapping element, `data-modal-target="dialog"` on the `<dialog>`.
- `data-action="click->modal#open"` on a plain "Add X" button just opens the dialog (`modal#open`).
- Edit links instead use `data: { turbo_frame: "<name>_edit_frame", action: "click->modal#openFrame" }` — `openFrame` opens the dialog *and* lets Turbo intercept the click to load the edit form into a same-page named frame (`property_edit_frame`, `expense_edit_frame`, `payment_edit_frame`, `agreement_edit_frame`, `note_edit_frame`), each nested inside its own modal's `shared/_modal` box.
- `dialogTargetConnected` in `modal_controller.js` fires whenever a `<dialog>` element is (re)connected — including when a Turbo Frame swap replaces the section frame it lives in after a create/edit submit. If the freshly rendered dialog contains a `[role="alert"]` (validation errors), it reopens itself automatically; a clean re-render (success) stays closed. It does NOT fire for the nested edit-frame GET that merely loads the form, so opening via `openFrame` is never mistaken for a submit result.
- Cancel buttons just `data-action="modal#close"`.

### Section frames and validation-failure re-render
Each show page tab wraps its table + form in one section frame per resource: `dom_id(@property, :header|:agreements|:expenses|:notes|:tax_report)` on `properties/show.html.erb`, `dom_id(@agreement, :header|:payments|:notes)` on `rental_agreements/show.html.erb`. Create/update forms live inside their section frame, so a normal Turbo submit (success or failure) only replaces that frame.
- On validation failure, `ExpensesController`, `RentalAgreementsController`, `PropertiesController`, and `PaymentsController` don't re-render their own template — they `render template: "properties/show"` (or `"rental_agreements/show"`) so Turbo can extract the *same* section frame with errors in place. This requires every ivar the target `show` template needs, which `PropertyShowLoadable#load_property_show_data` and `AgreementShowLoadable#load_agreement_show_data` (both in `app/controllers/concerns/`) rebuild.
- The tax report tab is lazy-loaded, not part of that ivar rebuild: `turbo_frame_tag dom_id(@property, :tax_report), src: tax_report_property_path(@property), loading: :lazy` fetches `PropertiesController#tax_report` only when the tab frame becomes visible.

### Tabs
`shared/_dashboard_layout` pages use `data-controller="tabs" data-tabs-active-tab-value="<name>"` on the wrapper, with nav links (`data: { tabs_tab: "<name>", action: "click->tabs#selectTab" }`) and matching `data-tab-section="<name>"` panels. The `tabs` Stimulus controller (`app/javascript/controllers/tabs_controller.js`) toggles panel visibility and swaps the `tab-link-active` class — no server round-trip, all tabs' content is present in the DOM at once (except the lazy tax-report frame above).

### Edit pages as modal fallback / direct navigation
`properties/edit.html.erb`, `expenses/edit.html.erb`, `payments/edit.html.erb`, `rental_agreements/edit.html.erb`, `notes/edit.html.erb` are thin wrappers: `render layout: "shared/frame_page", locals: { frame_id: "<name>_edit_frame" }` around the same `_edit_modal_content` partial used inside the modal. `shared/_frame_page` gives a centered card shell with the named turbo frame inside, so the same edit view works both loaded into a modal via Turbo Frame navigation and as a full-page direct visit.

### Notes
`notes/_notes_list.html.erb` is shared by the property tab, agreement tab, and the standalone `notes/index.html.erb` — takes `notes:` and optional `note_frame_id:` locals, renders the table (or empty state) plus a `note_edit_frame` modal. `notes/_form.html.erb` is likewise shared for new-note creation across all three call sites, taking `note:`, `noteable:` (nil for general notes), and `frame:` locals.

## Coding conventions
- Standard Rails conventions; thin controllers, logic in models or service objects
- Service objects as plain Ruby classes under `app/services/`
- Use `enum` for status fields
- DB-level constraints for everything important: foreign keys, not-null, unique indexes
- Prefer `present?` / `blank?` over manual nil checks

## Internationalization (i18n)
**All displayable text must use the i18n framework.** No hardcoded user-facing strings in views, controllers, or models.

**How to implement:**
- **Views:** Use `t("key.path")` for all text, buttons, labels, placeholders, hints, etc.
- **Models:** Use `I18n.t("key.path")` for validation error messages, enum display values, and any user-facing strings
- **Controllers:** Use `t("key.path")` for flash messages and alerts
- **Translation files:** Update both `config/locales/en.yml` and `config/locales/es.yml` whenever adding new user-facing text

**Key translation files:**
- `config/locales/en.yml` — English translations
- `config/locales/es.yml` — Spanish translations

**Translation structure** follows Rails conventions:
```yaml
en:
  properties:
    my_properties: My Properties
    form:
      name_label: Name
    errors:
      not_found: Property not found
```

**When in doubt:**
- Never render strings like `"Active"`, `"Pending"`, `"Save"`, `"Cancel"`, `"Delete"` without i18n
- Enum display values should be translated
- Flash messages should be translated
- Form labels, hints, and placeholders should be translated
- Error messages should be translated
- Any text visible to the user should be translated
- RSpec, not Minitest
- FactoryBot for fixtures
- Test models and controllers; skip view specs
- At minimum a smoke test for every new controller action

## Frontend / UI conventions
- **Tooling:** Tailwind CSS + DaisyUI 5 via CDN. Theme is `emerald` — do not change without being asked.
- **Navbar:** lives in `app/views/layouts/application.html.erb`. Use DaisyUI `navbar`.
- **Forms:** fields stack vertically. Label above, full-width input below (`input input-bordered w-full`). Never put fields side by side. Action buttons on their own row at the bottom. Wrap in `max-w-md`. Checkboxes always have a visible text label next to them.
- **Buttons:** primary = `btn btn-primary`, destructive = `btn btn-error`, cancel = `btn btn-ghost`.
- **Tables:** per-row actions sit inline horizontally in the row, not stacked.
- **Components:** use DaisyUI semantic components (card, table, badge, navbar, btn, input, alert).
- **Mobile:** forms and tables must not overflow on small widths.
- **Accessibility:** labels associated with inputs via `for`/`id` or wrapping.
- **Avatar colors:** Property avatars use deterministic color assignment from a fixed palette (6 colors: success, warning, error, info, primary, secondary). Color is derived by hashing the property name (`Digest::MD5`, stable across processes/restarts) to an index — same property name always gets the same color across renders and sessions. See `app/helpers/avatar_helper.rb` for implementation. This ensures visual consistency without requiring image uploads or database storage.

## Workflow
Before writing any code, always present your analysis and implementation plan and wait for the user's approval. Never jump straight into writing files.

## Environment
This project runs in a devcontainer. Claude cannot install packages or system dependencies — never attempt `apt-get`, `gem install`, `brew`, or similar. State what needs installing and the user will do it from the host.

Claude may run Rails commands directly (`bin/rails db:migrate`, `bin/rspec`, generators, etc.). The user runs the dev server themselves (`bin/rails s`).

## Browsing the running app with Playwright
The Rails server runs in the devcontainer (`bin/rails s`). Use `http://localhost:3000` as the base URL for all navigation and Playwright interactions.

## Testing
- **RSpec unit/controller tests:** `bin/rspec`
- **Playwright tests:** `npm test` (generates report at `playwright-report/index.html`)
- **Playwright report:** Open `playwright-report/index.html` in a browser to view detailed test results, traces, and screenshots

## Common commands
```bash
bin/rails db:create db:migrate
bin/rails db:seed
bin/rspec
bin/rails s
npm test
```

## Git commits
**CRITICAL: Never commit anything to git without explicit permission from the user.** If you make changes that you believe should be committed, ask for approval first. Do not commit as part of a task unless the user specifically asks you to.

---

## Future direction — DO NOT IMPLEMENT
The original vision includes models not yet built. These **do not exist** in the codebase. Listed only to show where the project may head:
```
Unit       # belongs_to :property; has_many :leases
Lease      # belongs_to :unit, :tenant, :landlord
Task       # belongs_to :landlord; optional polymorphic taskable
Document   # belongs_to :landlord; polymorphic documentable
```
Notes on what *is* built (don't confuse with the above):
- `Payment` belongs to `RentalAgreement`, not `Lease`.
- Tenants exist, but not as a standalone `Tenant` model — a tenant is a `User` linked to a `RentalAgreement` via `AgreementTenant`. There is no `Unit`/`Lease` layer; agreements attach directly to a `Property`.
- `Task` isn't built, but `Note` (polymorphic `noteable`, with due dates and completion) covers part of that ground.
