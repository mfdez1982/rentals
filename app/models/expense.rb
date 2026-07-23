class Expense < ApplicationRecord
  belongs_to :property
  has_many :recollections, dependent: :restrict_with_error

  enum :category, {
    tax: 0,
    insurance: 1,
    utilities: 2,
    community_fees: 3,
    repairs_maintenance: 4,
    management_legal: 5,
    financing: 6,
    other: 7
  }

  validates :date, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :category, presence: true
  validates :invoice_url, allow_blank: true,
    format: { with: %r{\Ahttps?://.+}i, message: :invalid_url }
  validates :period_start, :period_end, presence: true, if: :collectable?
  validate :period_end_after_start, if: :collectable?

  scope :deductible, -> { where(deductible: true) }
  scope :collectable, -> { where(collectable: true) }

  def period_days
    return nil if period_start.blank? || period_end.blank?
    (period_end - period_start).to_i + 1
  end

  private

  def period_end_after_start
    return unless period_start && period_end
    errors.add(:period_end, I18n.t("expenses.errors.period_end_before_start")) if period_end < period_start
  end
end
