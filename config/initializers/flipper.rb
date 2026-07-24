# Flipper drives plan-based feature entitlements.
#
# A landlord's tier lives on `Landlord#plan` (the single source of truth). These
# groups map that plan onto the set of features a tier unlocks, so every future
# gate is a one-line check against `current_landlord`, e.g.:
#
#   Flipper.enabled?(:tax_report, current_landlord)
#
# To change what a tier includes, enable/disable a feature for a group here or
# via the Flipper UI — no code change at the call sites.

require "flipper/adapters/active_record"

Flipper.configure do |config|
  config.adapter { Flipper::Adapters::ActiveRecord.new }
end

# Landlords on Pro or Premium.
Flipper.register(:pro_and_up) do |actor, _context|
  actor.respond_to?(:plan) && %w[pro premium].include?(actor.plan)
end

# Landlords on Premium only.
Flipper.register(:premium_only) do |actor, _context|
  actor.respond_to?(:plan) && actor.plan == "premium"
end
