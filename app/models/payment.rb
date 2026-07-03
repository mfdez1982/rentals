class Payment < ApplicationRecord
  belongs_to :rental_agreement

  validates :due_date, :amount, presence: true
  validates :amount, numericality: { greater_than: 0 }, allow_nil: true

  def overdue?
    paid_date.nil? && due_date.present? && due_date < Date.today
  end
end
