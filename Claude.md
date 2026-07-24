# Rentals SaaS — Project Context for Claude Code

@docs/DEVELOPER_ONBOARDING.md
@docs/PRODUCT_OVERVIEW.md

The two imports above are the full technical and business context for this project — how the code is organized, the domain model, Turbo Frame patterns, and the product's reasoning and rules. Everything below this point is about **how Claude should work in this repo**, not what the app does.

## What this project is
A multi-landlord SaaS app for personal rental property management. Small landlords (1–5 properties each) sign up, log in, and manage their own properties. Each landlord sees only their own data.

## Reading the current code
Schema, models, routes, controllers, and view structure are all readable from the source files themselves — do not keep a copy here, it only goes stale. When you need them:
- Schema → `db/schema.rb`
- Models and their methods → `app/models/`
- Routes → `config/routes.rb`
- Controllers → `app/controllers/`
- Views → `app/views/`

## Multi-tenancy (critical)
Every query must be scoped to `current_landlord`. Never rely on the view alone. Always scope from `current_landlord` down the full chain:
```ruby
@property  = current_landlord.properties.find(params[:property_id])
@agreement = @property.rental_agreements.find(params[:rental_agreement_id])
@payment   = @agreement.payments.find(params[:id])
```
`current_landlord` is defined in `ApplicationController` as `current_user&.landlord`. In development, it auto-signs-in `dev@example.com` if that user exists.

**Tenant-facing access is separate.** Tenants don't own a `Landlord`, so they reach their data through their accepted `AgreementTenant` rows, not `current_landlord` — scope those queries from `current_user` (e.g. `current_user.tenant_rental_agreements`). Don't leak a landlord's full agreement/property data into a tenant view; expose only what the tenancy grants.

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
- **Tables:** per-row actions sit inline horizontally in the row, not stacked. Use the standard `table table-zebra` sizing — do NOT use `table-sm` (its smaller font is inconsistent with the rest of the app).
- **Row delete action:** ALWAYS use the bin (trash) heroicon as an `icon-btn`, never a text "Delete" button — `button_to ... class: "icon-btn"` wrapping `heroicon "trash", variant: :outline` (see `app/views/expenses/_expense.html.erb`).
- **Components:** use DaisyUI semantic components (card, table, badge, navbar, btn, input, alert).
- **Mobile:** forms and tables must not overflow on small widths.
- **Accessibility:** labels associated with inputs via `for`/`id` or wrapping.
- **Avatar colors:** Property avatars use deterministic color assignment from a fixed palette (6 colors: success, warning, error, info, primary, secondary). Color is derived by hashing the property name (`Digest::MD5`, stable across processes/restarts) to an index — same property name always gets the same color across renders and sessions. See `app/helpers/avatar_helper.rb` for implementation. This ensures visual consistency without requiring image uploads or database storage.

## Workflow
Before writing any code, always present your analysis and implementation plan and wait for the user's approval. Never jump straight into writing files.

Keep plans at the level of intent and behavior, not implementation minutiae. Say what you'll add and how it behaves ("I'll add a Validate button that opens a popup listing the offending expenses"), but do NOT spell out low-level details like CSS/DaisyUI class names, Stimulus wiring, ivar/variable names, or exact file-by-file line edits. The user reviews the actual code after the fact — the plan is for agreeing on approach, not for pre-reading the implementation.

## Environment
This project runs in a devcontainer. Claude cannot install packages or system dependencies — never attempt `apt-get`, `gem install`, `brew`, or similar. State what needs installing and the user will do it from the host.

Claude may run Rails commands directly (`bin/rails db:migrate`, `bin/rspec`, generators, etc.). The user runs the dev server themselves (`bin/rails s`).

## Browsing the running app with Playwright
The Rails server runs in the devcontainer (`bin/rails s`) on port 3000, but that's forwarded to **port 3001 on the host**. Claude cannot drive a local Playwright browser from inside the devcontainer — instead, use the Playwright MCP tools, which connect to an MCP server running on the host at `host.docker.internal:3002/mcp`. Use `http://localhost:3001` as the base URL for navigation within those tool calls (not 3000 — that's the container-internal port and is unreachable from the host-side browser).

This depends on host-side state Claude cannot see or start:
- The Playwright MCP server process must be running on the host. If tool calls fail with a connection error (including `browser_tabs`, which doesn't even touch the target URL), the MCP server itself is probably not running — ask the user to start it, don't assume the Rails server is at fault.
- The MCP server's browser (`chrome-for-testing` channel) must be installed on the host. If a tool call errors with "Browser chrome-for-testing is not installed," ask the user to run `npx playwright install chrome` on the host (not `npx @playwright/mcp install-browser ...` — that subcommand doesn't exist in the installed version).
- Any command needing to run on the host (checking process state, installing browsers, verifying ports) must be run by the user — Claude's Bash tool only executes inside the devcontainer and cannot diagnose or fix host-side issues directly.

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
