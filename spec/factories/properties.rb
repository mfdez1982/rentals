FactoryBot.define do
  factory :property do
    association :landlord
    name { "Test Property" }
  end
end
