class RentalAgreement < ApplicationRecord
  belongs_to :property
  has_many :payments, dependent: :destroy
  has_many :notes, as: :noteable, dependent: :destroy
  has_many :agreement_tenants, dependent: :destroy
  has_many :tenants, -> { where(agreement_tenants: { status: :accepted }) }, through: :agreement_tenants, source: :user
  has_many :recollections, dependent: :restrict_with_error

  validates :start_date, :end_date, :rent_amount, presence: true
  validates :rent_amount, numericality: { greater_than: 0 }, allow_nil: true
  validate :end_date_after_start_date
  validate :no_overlapping_agreements

  scope :active,   -> { where("start_date <= ? AND end_date >= ?", Date.today, Date.today) }
  scope :upcoming, -> { where("start_date > ?", Date.today) }
  scope :expired,  -> { where("end_date < ?", Date.today) }
  scope :sorted,   -> { order(start_date: :desc) }
  scope :overlapping, ->(from, to) { where("start_date <= ? AND end_date >= ?", to, from) }

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

  def accepted_agreement_tenants
    agreement_tenants.where(status: :accepted)
  end

  # This agreement's date range clamped into the inclusive window [from, to],
  # or nil if it does not overlap the window at all.
  def clamped_range(from, to)
    clamped_start = [ start_date, from ].max
    clamped_end   = [ end_date, to ].min
    return nil if clamped_start > clamped_end
    clamped_start..clamped_end
  end

  # Inclusive number of days this agreement covers within [from, to].
  def days_within(from, to)
    range = clamped_range(from, to)
    return 0 unless range
    (range.end - range.begin).to_i + 1
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date
    errors.add(:end_date, I18n.t("rental_agreements.errors.end_date_after_start")) if end_date <= start_date
  end

  def no_overlapping_agreements
    return unless start_date && end_date && property_id
    scope = property.rental_agreements.overlapping(start_date, end_date)
    scope = scope.where.not(id: id) if persisted?
    errors.add(:base, I18n.t("rental_agreements.errors.overlapping")) if scope.exists?
  end
end
