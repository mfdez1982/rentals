class AgreementTenant < ApplicationRecord
  INVITE_TTL = 14.days

  belongs_to :rental_agreement
  belongs_to :user, optional: true

  enum :status, { pending: 0, accepted: 1, rejected: 2, removed: 3 }, default: :pending

  has_secure_token :invitation_token

  before_validation :normalize_email
  before_validation :set_invited_at

  validates :invited_email, presence: true
  validates :status, presence: true
  validates :invited_at, presence: true
  validates :rental_agreement, presence: true

  scope :live, -> { where(status: [ :pending, :accepted ]) }
  scope :for_email, ->(email) { where(invited_email: email.to_s.downcase.strip) }

  def expired?
    pending? && invited_at.present? && invited_at < INVITE_TTL.ago
  end

  def claimable?
    pending? && !expired?
  end

  private

  def normalize_email
    self.invited_email = invited_email.downcase.strip if invited_email.present?
  end

  def set_invited_at
    self.invited_at ||= Time.current
  end
end
