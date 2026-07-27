class Expense < ApplicationRecord
  belongs_to :property
  has_many :recollections, dependent: :restrict_with_error

  # A single supporting document (invoice/receipt) stored in the app. Purged
  # when the expense is destroyed.
  has_one_attached :invoice_document

  INVOICE_DOCUMENT_MAX_BYTES = 10.megabytes
  INVOICE_DOCUMENT_CONTENT_TYPE = "application/pdf".freeze

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
  validates :period_start, :period_end, presence: true, if: :collectable?
  validate :period_end_after_start, if: :collectable?
  validate :acceptable_invoice_document

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

  def acceptable_invoice_document
    return unless invoice_document.attached?

    unless invoice_document.content_type == INVOICE_DOCUMENT_CONTENT_TYPE
      errors.add(:invoice_document, I18n.t("expenses.invoice_document.errors.not_pdf"))
    end

    if invoice_document.byte_size > INVOICE_DOCUMENT_MAX_BYTES
      errors.add(:invoice_document, I18n.t("expenses.invoice_document.errors.too_large",
                                           limit: INVOICE_DOCUMENT_MAX_BYTES / 1.megabyte))
    end
  end
end
