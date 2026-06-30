FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "landlord#{n}@example.com" }
    password { "password123" }
  end
end
