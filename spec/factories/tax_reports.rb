FactoryBot.define do
  factory :tax_report do
    association :property
    year { 2025 }
    total_days { 365 }
    active_rental_days { 214 }
    pro_rata_ratio { 0.5863 }
    total_gross_income { 560.00 }
    expense_lines do
      [
        {
          "date" => "2025-01-01",
          "category" => "tax",
          "description" => "IBI",
          "original_amount" => "82.63",
          "deductible_amount" => "48.45"
        }
      ]
    end
  end
end
