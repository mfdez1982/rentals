class Payment < ApplicationRecord
  belongs_to :rental_agreement

  validates :due_date, :amount, presence: true
  validates :amount, numericality: { greater_than: 0 }, allow_nil: true
  validate :paid_date_not_before_due_date

  def overdue?
    paid_date.nil? && due_date.present? && due_date < Date.today
  end

  private

  def paid_date_not_before_due_date
    return unless due_date && paid_date
    errors.add(:paid_date, "cannot be before due date") if paid_date < due_date
  end
end
