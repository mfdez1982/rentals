FactoryBot.define do
  factory :property do
    association :landlord
    name { "Test Property" }
    rented { false }
  end
end
