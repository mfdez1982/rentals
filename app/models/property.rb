class Property < ApplicationRecord
  belongs_to :landlord
  has_many :rental_agreements, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :notes, as: :noteable, dependent: :destroy

  validates :name, presence: true

  def rented?
    rental_agreements.active.exists?
  end

  def has_overdue_payments?
    rental_agreements.any?(&:has_overdue_payments?)
  end

  def earliest_tax_year
    earliest_agreement_year = rental_agreements.minimum(:start_date)&.year
    earliest_expense_year = expenses.minimum(:date)&.year
    [earliest_agreement_year, earliest_expense_year].compact.min || Date.today.year
  end

  def active_rental_agreement
    rental_agreements.active.first
  end

  def next_unpaid_payment
    rental_agreements.flat_map(&:payments)
                     .select { |p| p.paid_date.nil? }
                     .min_by(&:due_date)
  end

  def max_days_overdue
    overdue_payments = rental_agreements.flat_map(&:payments).select(&:overdue?)
    return 0 if overdue_payments.empty?
    overdue_payments.map { |p| (Date.today - p.due_date).to_i }.max
  end

  private

  def overdue_payments
    rental_agreements.flat_map(&:payments).select(&:overdue?)
  end
end
