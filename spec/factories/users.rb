FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "landlord#{n}@example.com" }
    password { "password123" }
    role { :landlord }

    trait :landlord do
      role { :landlord }
    end

    trait :admin do
      role { :admin }
      sequence(:email) { |n| "admin#{n}@example.com" }
    end
  end
end
