FactoryBot.define do
  factory :landlord do
    association :user
    name { "Test Landlord" }
    phone { nil }
  end
end
