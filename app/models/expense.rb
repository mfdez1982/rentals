class Expense < ApplicationRecord
  belongs_to :property

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
    format: { with: %r{\Ahttps?://.+}i, message: "must be a valid URL" }
end
