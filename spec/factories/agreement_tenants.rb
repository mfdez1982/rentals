FactoryBot.define do
  factory :agreement_tenant do
    association :rental_agreement
    sequence(:invited_email) { |n| "tenant#{n}@example.com" }
    invited_at { Time.current }
    status { :pending }

    trait :accepted do
      status { :accepted }
      association :user
    end

    trait :rejected do
      status { :rejected }
    end

    trait :removed do
      status { :removed }
    end

    trait :expired do
      status { :pending }
      invited_at { (AgreementTenant::INVITE_TTL + 1.day).ago }
    end
  end
end
