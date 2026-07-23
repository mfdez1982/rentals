class Property < ApplicationRecord
  belongs_to :landlord
  has_many :rental_agreements, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :notes, as: :noteable, dependent: :destroy
  has_many :recollections, through: :expenses
  has_many :tax_reports, dependent: :destroy

  validates :name, presence: true

  def rented?
    rental_agreements.any?(&:active?)
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
    rental_agreements.detect(&:active?)
  end

  def next_unpaid_payment
    rental_agreements.flat_map(&:payments)
                     .select { |p| p.paid_date.nil? }
                     .min_by(&:due_date)
  end
end
