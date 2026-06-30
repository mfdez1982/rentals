# Rentals SaaS — Project Context for Claude Code

## What this project is
A multi-landlord SaaS app for personal rental property management. Small landlords (1–5 properties each) sign up, log in, and manage their own properties, tenants, leases, payments, tasks, and documents. Each landlord sees only their own data.

## Tech stack
- Ruby on Rails 8, PostgreSQL
- Devise for authentication (User model; Landlord is a separate profile model)
- ERB views — no React, no TypeScript
- ActiveStorage for file uploads
- RSpec + FactoryBot for testing

## Domain model

```
User           # Devise auth — email + password
Landlord       # belongs_to :user; owns all domain records
Property       # belongs_to :landlord; has_many :units, :tasks, :documents
Unit           # belongs_to :property; has_many :leases
Tenant         # belongs_to :landlord; has_many :leases
Lease          # belongs_to :unit, :tenant, :landlord
               # fields: start_date, end_date, monthly_rent, deposit, status
               # has_many :payments, :tasks, :documents
Payment        # belongs_to :lease; fields: amount, date, notes
Task           # belongs_to :landlord
               # optional polymorphic: belongs_to :taskable (Property or Lease)
               # fields: title, due_date, status (open/done), category
Document       # belongs_to :landlord
               # polymorphic: belongs_to :documentable (Property, Lease, Tenant)
               # has_one_attached :file (ActiveStorage)
```

## Multi-tenancy (critical)
Every query must be scoped to `current_landlord`. No record should ever be accessible to a landlord who doesn't own it. Scope from `current_landlord` down in controllers — never rely on the view alone. Example: `current_landlord.properties.find(params[:id])`.

## Coding conventions
- Standard Rails conventions; thin controllers, logic in models or service objects
- Service objects as plain Ruby classes under `app/services/`
- Use `enum` for status fields
- DB-level constraints for everything important: foreign keys, not-null, unique indexes
- Prefer `present?` / `blank?` over manual nil checks
- Simple, readable code over clever code

## Testing
- RSpec, not Minitest
- FactoryBot for fixtures
- Test models and controllers; skip view specs
- At minimum a smoke test for every new controller action

## Workflow
Before writing any code, always present your analysis and implementation plan and wait for the user's approval. Never jump straight into writing files.

## Environment
This project runs in a devcontainer. Claude cannot install packages or system dependencies — never attempt `apt-get`, `gem install`, `brew`, or similar. Instead, clearly state what needs to be installed and the user will do it from the host.

The user runs all Rails commands themselves (server, migrations, seeds, tests, generators, etc.). Claude only writes and edits files — never executes `bin/rails`, `bin/rspec`, or similar commands.

## Common commands
```bash
bin/rails db:create db:migrate
bin/rails db:seed
bin/rspec
bin/rails s
```
