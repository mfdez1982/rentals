FactoryBot.define do
  factory :recollection do
    transient do
      property { create(:property) }
    end

    expense { create(:expense, :collectable, property: property) }
    rental_agreement { create(:rental_agreement, property: property) }
    period_start { expense.period_start }
    period_end { expense.period_end }
    amount { 50.00 }
    due_date { Date.new(2025, 7, 1) }
    status { :pending }
    paid_date { nil }

    trait :paid do
      status { :paid }
      paid_date { Date.today }
    end

    trait :overdue do
      status { :pending }
      due_date { Date.yesterday }
      paid_date { nil }
    end

    trait :with_tenant do
      agreement_tenant { create(:agreement_tenant, :accepted, rental_agreement: rental_agreement) }
    end
  end
end
