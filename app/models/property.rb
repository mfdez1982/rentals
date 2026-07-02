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
end
