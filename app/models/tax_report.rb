class TaxReport < ApplicationRecord
  belongs_to :property

  validates :year, :total_days, :active_rental_days, :pro_rata_ratio, :total_gross_income, presence: true

  # Snapshots are immutable once generated: they can be created and destroyed,
  # but never updated.
  before_update { raise ActiveRecord::ReadOnlyRecord }

  # Convenience totals over the frozen expense-line snapshot.
  def total_original_amount
    expense_lines.sum { |line| line["original_amount"].to_d }
  end

  def total_deductible_amount
    expense_lines.sum { |line| line["deductible_amount"].to_d }
  end
end
