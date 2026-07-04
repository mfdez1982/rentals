FactoryBot.define do
  factory :payment do
    association :rental_agreement
    due_date { Date.new(2025, 6, 1) }
    amount { 80.00 }
    paid_date { nil }
  end
end
