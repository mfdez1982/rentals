class Payment < ApplicationRecord
  belongs_to :rental_agreement

  validates :due_date, :amount, presence: true
  validates :amount, numericality: { greater_than: 0 }, allow_nil: true

  def overdue?
    paid_date.nil? && due_date.present? && due_date < Date.today
  end

  # An overdue payment is due a reminder if it has never been reminded, or the
  # last reminder is older than the cadence interval. The interval lives in the
  # dispatching service, so changing the cadence applies cleanly to every row.
  def reminder_due?(interval:, now: Time.current)
    overdue? && (last_reminded_at.nil? || last_reminded_at <= now - interval)
  end
end
