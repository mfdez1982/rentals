FactoryBot.define do
  factory :rental_agreement do
    association :property
    start_date { Date.new(2025, 6, 1) }
    end_date { Date.new(2026, 5, 31) }
    rent_amount { 80.00 }
  end
end
