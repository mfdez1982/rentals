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

Derived state (never stored as a column):
- `property.rented?` — true if any agreement is active today
- `payment.overdue?` — true when `paid_date` is nil and `due_date < Date.today`
- `rental_agreement.has_overdue_payments?` — any payment is overdue
- `property.has_overdue_payments?` — any agreement has overdue payments
- `property.active_rental_agreement` — returns the currently active agreement (if any)
- `property.next_unpaid_payment` — gets the soonest unpaid payment from any agreement
- `property.max_days_overdue` — calculates maximum days overdue across all payments

## Implemented features
- Property management with derived rented/available status
- Rental agreements per property, with renew-with-prefill (start date + rent copied from the prior agreement)
- Payments per agreement, including bulk/recurring generation (start date + number of months) and overdue tracking
- Deductible expenses per property, categorized (`Expense.category` enum)
- Tax report per property/year: pro-rata deductible ratio based on active rental days, gross income, deductible expense breakdown
- Devise auth (sign up/in/out, account edit, account deletion) — password reset is currently broken (submitting throws a 500)
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

## Turbo Frame patterns
These are non-obvious and hard to reconstruct from the code alone — read this before touching any inline-edit or agreements flow.

### Properties index — inline edit
Each property row is wrapped in `turbo_frame_tag dom_id(property)`:
- Clicking **Edit** navigates the frame to `edit_property_path`, which returns a frame with a form using `form_data: { turbo_frame: "_top" }`. Submit breaks out to `_top` and does a full-page redirect to `properties_path`.
- Clicking **Cancel** navigates the frame to `property_path(property)`. `show.html.erb` contains a hidden `turbo_frame_tag dom_id(@property), style: "display:none"` that renders the property row — Turbo extracts it to restore the row.
- The `properties` Stimulus controller closes other open edit frames: `data-controller="properties"` on the table, `data: { action: "click->properties#openEdit" }` on Edit links, `data: { row_url: property_path(property) }` on each frame.

### Properties show — rental agreements
`show.html.erb` has two frames:
1. **Hidden row frame** `turbo_frame_tag dom_id(@property), style: "display:none"` — renders the `_property` partial invisibly. Used only by the index inline-edit cancel/restore flow.
2. **Outer agreements frame** `turbo_frame_tag dom_id(@property, :agreements)` — wraps the entire agreements section (table + new-agreement form). Frame ID e.g. `agreements_property_1`.
   - **Create**: new form is inside this frame → auto-targets it → success redirect to `property_path` refreshes the outer frame.
   - **Delete**: `button_to` with `form: { data: { turbo_frame: dom_id(property, :agreements) } }` targets the outer frame → success redirect refreshes the list.
   - **Renew**: link with `data: { turbo_frame: dom_id(property, :agreements) }` navigates the outer frame to `new_path?source_id=X`. `new.html.erb` wraps its content in the outer frame. The `new` action pre-fills `start_date = source.end_date + 1.day` and `rent_amount` when `params[:source_id]` is given.
   - **Inline edit**: each row is wrapped in `turbo_frame_tag dom_id(agreement), data: { row_url: property_path(@property) }`. Clicking Edit navigates the inner frame to `edit.html.erb`. Success redirect to `property_path` → Turbo finds the inner frame nested inside the outer frame and refreshes it.
   - The `rental-agreements` Stimulus controller (same logic as `properties`) handles closing other open edit rows.

### Agreement show — payments
`rental_agreements/show.html.erb` uses the same outer/inner frame pattern:
- **Outer frame** `dom_id(@agreement, :payments)` wraps the payments table + Add Payment form.
- **Create**: form auto-targets the outer frame; success/failure redirect/render refreshes it.
- **Delete**: `button_to` with `form: { data: { turbo_frame: dom_id(agreement, :payments) } }` targets outer frame.
- **Inline edit**: each payment row is wrapped in `turbo_frame_tag dom_id(payment), data: { row_url: property_rental_agreement_path(...) }`. Edit navigates the inner frame; success redirect → Turbo finds the inner frame nested inside the outer frame.
- The `payments` Stimulus controller (same `openEdit` logic) closes other open edit rows.
- On `PaymentsController#create` failure: sets `@payments` and `@new_payment`, then `render template: "rental_agreements/show"` so Turbo extracts the outer frame with errors.

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
- **Avatar colors:** Property avatars use deterministic color assignment from a fixed palette (6 colors: success, warning, error, info, primary, secondary). Color is derived by hashing the property name to an index — same property name always gets the same color across renders and sessions. See `app/helpers/avatar_helper.rb` for implementation. This ensures visual consistency without requiring image uploads or database storage.

## Workflow
Before writing any code, always present your analysis and implementation plan and wait for the user's approval. Never jump straight into writing files.

## Environment
This project runs in a devcontainer. Claude cannot install packages or system dependencies — never attempt `apt-get`, `gem install`, `brew`, or similar. State what needs installing and the user will do it from the host.

The user runs all Rails commands themselves (server, migrations, seeds, tests, generators, etc.). Claude only writes and edits files — never executes `bin/rails`, `bin/rspec`, or similar.

## Browsing the running app with Playwright
The Rails server runs on the **host** machine (`bin/rails s`), not inside this devcontainer, and the Playwright MCP server also runs on the host (reachable from the container at `host.docker.internal:3001`). Because the Playwright browser itself executes on the host, navigate using `http://localhost:3000` (not `host.docker.internal:3000` — that fails with `ERR_NAME_NOT_RESOLVED` since it's resolved from inside the browser's own host context, not the container's).
- Confirm with the user that `bin/rails s` is running on the host before attempting to navigate.
- Use `http://localhost:3000/...` as the base URL for all `mcp__playwright__browser_*` tool calls.

## Common commands
```bash
bin/rails db:create db:migrate
bin/rails db:seed
bin/rspec
bin/rails s
```

## Git commits
**CRITICAL: Never commit anything to git without explicit permission from the user.** If you make changes that you believe should be committed, ask for approval first. Do not commit as part of a task unless the user specifically asks you to.

---

## Future direction — DO NOT IMPLEMENT
The original vision includes models not yet built. These **do not exist** in the codebase. Listed only to show where the project may head:
```
Unit       # belongs_to :property; has_many :leases
Tenant     # belongs_to :landlord; has_many :leases
Lease      # belongs_to :unit, :tenant, :landlord
Task       # belongs_to :landlord; optional polymorphic taskable
Document   # belongs_to :landlord; polymorphic documentable
```
Note: `Payment` *is* built but belongs to `RentalAgreement`, not `Lease`.
