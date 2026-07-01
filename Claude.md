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

## Database schema (current)

```
users
  id, email, encrypted_password, reset_password_token,
  reset_password_sent_at, remember_created_at, role(int default 0), timestamps

landlords
  id, user_id(FK), name(not null), phone, timestamps

properties
  id, landlord_id(FK), name(not null), timestamps

rental_agreements
  id, property_id(FK), start_date(date not null), end_date(date not null),
  rent_amount(decimal 10,2 not null), timestamps
```

## Models (current)

```ruby
User
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable
  has_one :landlord, dependent: :destroy
  enum :role, { landlord: 0, admin: 1 }, default: :landlord
  after_create :create_landlord  # auto-creates Landlord on sign-up, name = email prefix

Landlord
  belongs_to :user
  has_many :properties, dependent: :destroy
  validates :name, presence: true

Property
  belongs_to :landlord
  has_many :rental_agreements, dependent: :destroy
  validates :name, presence: true
  def rented?  # derived — true if any agreement is active today

RentalAgreement
  belongs_to :property
  validates :start_date, :end_date, :rent_amount, presence: true
  validates :rent_amount, numericality: { greater_than: 0 }
  validate :end_date_after_start_date
  validate :no_overlapping_agreements  # no date-range overlaps per property, excluding self
  scope :active    # start_date <= today <= end_date
  scope :upcoming  # start_date > today
  scope :expired   # end_date < today
  scope :sorted    # order start_date desc
  def active?, upcoming?, expired?
  def status        # => "Active" | "Upcoming" | "Expired"
  def status_badge_class  # => DaisyUI badge class string
```

## Routes (current)

```
GET    /                                       root → properties#index
GET    /properties                             properties#index
POST   /properties                             properties#create
GET    /properties/:id                         properties#show
GET    /properties/:id/edit                    properties#edit
PATCH  /properties/:id                         properties#update
DELETE /properties/:id                         properties#destroy

GET    /properties/:property_id/rental_agreements/new        rental_agreements#new
POST   /properties/:property_id/rental_agreements            rental_agreements#create
GET    /properties/:property_id/rental_agreements/:id/edit   rental_agreements#edit
PATCH  /properties/:property_id/rental_agreements/:id        rental_agreements#update
DELETE /properties/:property_id/rental_agreements/:id        rental_agreements#destroy
```

## Controllers (current)

**ApplicationController** — `before_action :authenticate_user!`; defines `current_landlord`
  (`current_user&.landlord`). In development, auto-signs-in `dev@example.com` if it exists.

**PropertiesController** — standard CRUD scoped through `current_landlord.properties`.
  `show` loads `@agreements = @property.rental_agreements.sorted` and
  `@new_agreement = @property.rental_agreements.build`.

**RentalAgreementsController** — always scopes property via
  `current_landlord.properties.find(params[:property_id])`. `new` pre-fills
  `start_date = source.end_date + 1.day` and `rent_amount` when `params[:source_id]` is given.
  All success paths redirect to `property_path(@property)`.

## Views structure

```
app/views/
  layouts/application.html.erb   # navbar + main wrapper (max-w-5xl)
  shared/_nav.html.erb            # DaisyUI navbar; login/logout links
  dashboard/index.html.erb

  properties/
    index.html.erb                # "Add a Property" card + table of properties
    _form.html.erb                # name field only; used for create and inline edit
    _property.html.erb            # <tr> with name link, rented? badge, Edit/Delete buttons
    show.html.erb                 # property detail page (see Turbo patterns below)
    edit.html.erb                 # inline-edit turbo frame response

  rental_agreements/
    _form.html.erb                # start_date, end_date, rent_amount + Cancel link
    _rental_agreement.html.erb    # <tr> with dates, currency, status badge, Edit/Delete/Renew
    new.html.erb                  # outer-frame response (table + form) for Renew and create failure
    edit.html.erb                 # inner-frame response for inline row edit
```

## Turbo Frame patterns

### Properties index — inline edit
Each property row in the index is wrapped in `turbo_frame_tag dom_id(property)`:
- Clicking **Edit** navigates the frame to `edit_property_path` which returns
  `edit.html.erb` (a frame with a form using `form_data: { turbo_frame: "_top" }`).
  Submit breaks out to `_top` and does a full-page redirect to `properties_path`.
- Clicking **Cancel** (in the edit form) navigates the frame to `property_path(property)`.
  `show.html.erb` contains a hidden `turbo_frame_tag dom_id(@property), style: "display:none"`
  that renders the property row — Turbo extracts it to restore the row.
- The `properties` Stimulus controller closes other open edit frames:
  `data-controller="properties"` on the table; `data: { action: "click->properties#openEdit" }`
  on Edit links; `data: { row_url: property_path(property) }` on each frame.

### Properties show — rental agreements
`show.html.erb` has two frames:

1. **Hidden row frame** `turbo_frame_tag dom_id(@property), style: "display:none"` — renders
   the `_property` partial invisibly. Used only by the index inline-edit cancel/restore flow.

2. **Outer agreements frame** `turbo_frame_tag dom_id(@property, :agreements)` — wraps the
   entire agreements section (table + new-agreement form). Frame ID e.g. `agreements_property_1`.
   - **Create**: new form is inside this frame → auto-targets it → success redirect to
     `property_path` refreshes the outer frame.
   - **Delete**: `button_to` with `form: { data: { turbo_frame: dom_id(property, :agreements) } }`
     targets the outer frame → success redirect refreshes the list.
   - **Renew**: link with `data: { turbo_frame: dom_id(property, :agreements) }` navigates the
     outer frame to `new_path?source_id=X`. `new.html.erb` wraps its content in the outer frame.
   - **Inline edit**: each row is wrapped in `turbo_frame_tag dom_id(agreement),
     data: { row_url: property_path(@property) }`. Clicking Edit navigates the inner frame to
     `edit.html.erb`. Success redirect to `property_path` → Turbo finds the inner frame nested
     inside the outer frame on the show page and refreshes it.
   - The `rental-agreements` Stimulus controller (same logic as `properties`) handles
     closing other open edit rows.

## Multi-tenancy (critical)
Every query must be scoped to `current_landlord`. Never rely on the view alone.
Always scope from `current_landlord` down:
```ruby
@property = current_landlord.properties.find(params[:id])
@agreement = @property.rental_agreements.find(params[:id])
```

## Coding conventions
- Standard Rails conventions; thin controllers, logic in models or service objects
- Service objects as plain Ruby classes under `app/services/`
- Use `enum` for status fields
- DB-level constraints for everything important: foreign keys, not-null, unique indexes
- Prefer `present?` / `blank?` over manual nil checks

## Testing
- RSpec, not Minitest
- FactoryBot for fixtures
- Test models and controllers; skip view specs
- At minimum a smoke test for every new controller action

## Frontend / UI conventions
- **Tooling:** Tailwind CSS + DaisyUI 5 via CDN. Theme is `emerald` — do not change without being asked.
- **Navbar:** lives in `app/views/layouts/application.html.erb`. Use DaisyUI `navbar`.
- **Forms:** fields stack vertically. Label above, full-width input below (`input input-bordered w-full`).
  Never put fields side by side. Action buttons on their own row at the bottom. Wrap in `max-w-md`.
  Checkboxes always have a visible text label next to them.
- **Buttons:** primary = `btn btn-primary`, destructive = `btn btn-error`, cancel = `btn btn-ghost`.
- **Tables:** per-row actions sit inline horizontally in the row, not stacked.
- **Components:** use DaisyUI semantic components (card, table, badge, navbar, btn, input, alert).
- **Mobile:** forms and tables must not overflow on small widths.
- **Accessibility:** labels associated with inputs via `for`/`id` or wrapping.

## Workflow
Before writing any code, always present your analysis and implementation plan and wait for the
user's approval. Never jump straight into writing files.

## Environment
This project runs in a devcontainer. Claude cannot install packages or system dependencies —
never attempt `apt-get`, `gem install`, `brew`, or similar. State what needs installing and the
user will do it from the host.

The user runs all Rails commands themselves (server, migrations, seeds, tests, generators, etc.).
Claude only writes and edits files — never executes `bin/rails`, `bin/rspec`, or similar.

## Common commands
```bash
bin/rails db:create db:migrate
bin/rails db:seed
bin/rspec
bin/rails s
```

## Aspirational domain model (not yet built)
The original vision includes these models not yet implemented:
```
Unit       # belongs_to :property; has_many :leases
Tenant     # belongs_to :landlord; has_many :leases
Lease      # belongs_to :unit, :tenant, :landlord
           # fields: start_date, end_date, monthly_rent, deposit, status
           # has_many :payments, :tasks, :documents
Payment    # belongs_to :lease; fields: amount, date, notes
Task       # belongs_to :landlord; optional polymorphic taskable (Property or Lease)
           # fields: title, due_date, status (open/done), category
Document   # belongs_to :landlord; polymorphic documentable (Property, Lease, Tenant)
           # has_one_attached :file
```
