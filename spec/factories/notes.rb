FactoryBot.define do
  factory :note do
    association :landlord
    title { "Test Note" }
    description { "This is a test note" }
    status { :active }
    due_date { nil }
    completed_at { nil }

    trait :with_due_date do
      due_date { 1.week.from_now }
    end

    trait :overdue do
      due_date { 1.day.ago }
    end

    trait :completed do
      status { :completed }
      completed_at { Time.current }
    end
  end
end
