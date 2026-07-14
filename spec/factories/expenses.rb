FactoryBot.define do
  factory :expense do
    association :property
    date { Date.today }
    amount { 250.00 }
    category { :insurance }
    description { "Annual home insurance" }
    invoice_url { nil }

    trait :collectable do
      collectable { true }
      category { :utilities }
      period_start { Date.new(2025, 6, 1) }
      period_end { Date.new(2025, 6, 30) }
    end
  end
end
