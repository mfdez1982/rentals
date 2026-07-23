class TaxReport < ApplicationRecord
  belongs_to :property

  validates :year, :total_days, :active_rental_days, :pro_rata_ratio, :total_gross_income, presence: true

  # Snapshots are immutable once generated: the computed figures can never be
  # updated. Only the user-facing name may be edited after creation.
  before_update do
    raise ActiveRecord::ReadOnlyRecord unless (changed - %w[name updated_at]).empty?
  end

  # Convenience totals over the frozen expense-line snapshot.
  def total_original_amount
    expense_lines.sum { |line| line["original_amount"].to_d }
  end

  def total_deductible_amount
    expense_lines.sum { |line| line["deductible_amount"].to_d }
  end
end
