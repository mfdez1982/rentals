class RentalAgreement < ApplicationRecord
  belongs_to :property
  has_many :payments, dependent: :destroy
  has_many :notes, as: :noteable, dependent: :destroy

  validates :start_date, :end_date, :rent_amount, presence: true
  validates :rent_amount, numericality: { greater_than: 0 }, allow_nil: true
  validate :end_date_after_start_date
  validate :no_overlapping_agreements

  scope :active,   -> { where("start_date <= ? AND end_date >= ?", Date.today, Date.today) }
  scope :upcoming, -> { where("start_date > ?", Date.today) }
  scope :expired,  -> { where("end_date < ?", Date.today) }
  scope :sorted,   -> { order(start_date: :desc) }

  def active?
    start_date.present? && end_date.present? &&
      start_date <= Date.today && end_date >= Date.today
  end

  def upcoming?
    start_date.present? && start_date > Date.today
  end

  def expired?
    end_date.present? && end_date < Date.today
  end

  def has_overdue_payments?
    payments.any?(&:overdue?)
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date
    errors.add(:end_date, I18n.t("rental_agreements.errors.end_date_after_start")) if end_date <= start_date
  end

  def no_overlapping_agreements
    return unless start_date && end_date && property_id
    scope = property.rental_agreements
                    .where("start_date <= ? AND end_date >= ?", end_date, start_date)
    scope = scope.where.not(id: id) if persisted?
    errors.add(:base, I18n.t("rental_agreements.errors.overlapping")) if scope.exists?
  end
end
