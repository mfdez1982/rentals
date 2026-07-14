class Recollection < ApplicationRecord
  belongs_to :expense
  belongs_to :rental_agreement
  belongs_to :agreement_tenant, optional: true

  enum :status, { pending: 0, paid: 1 }, default: :pending

  delegate :property, to: :expense

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :period_start, :period_end, presence: true
  validate :period_end_after_start
  validate :rental_agreement_matches_expense_property
  validate :agreement_tenant_matches_rental_agreement

  scope :overdue, -> { pending.where("due_date < ?", Date.today) }

  def overdue?
    pending? && due_date.present? && due_date < Date.today
  end

  private

  def period_end_after_start
    return unless period_start && period_end
    errors.add(:period_end, I18n.t("recollections.errors.period_end_before_start")) if period_end < period_start
  end

  def rental_agreement_matches_expense_property
    return unless expense && rental_agreement
    return if rental_agreement.property_id == expense.property_id
    errors.add(:rental_agreement, I18n.t("recollections.errors.property_mismatch"))
  end

  def agreement_tenant_matches_rental_agreement
    return unless agreement_tenant && rental_agreement
    return if agreement_tenant.rental_agreement_id == rental_agreement_id
    errors.add(:agreement_tenant, I18n.t("recollections.errors.tenant_mismatch"))
  end
end
