FactoryBot.define do
  factory :expense do
    association :property
    date { Date.today }
    amount { 250.00 }
    category { :insurance }
    description { "Annual home insurance" }
    invoice_url { nil }
  end
end
