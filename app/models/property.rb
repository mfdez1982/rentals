class Property < ApplicationRecord
  belongs_to :landlord
  has_many :rental_agreements, dependent: :destroy
  has_many :expenses, dependent: :destroy

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
end
