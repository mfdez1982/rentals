class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  has_one :landlord, dependent: :destroy
  has_many :agreement_tenants, dependent: :destroy
  has_many :tenant_rental_agreements, -> { where(agreement_tenants: { status: :accepted }) }, through: :agreement_tenants, source: :rental_agreement

  enum :role, { landlord: 0, admin: 1 }, default: :landlord

  after_create :create_landlord, if: :landlord?

  def tenant?
    agreement_tenants.accepted.exists?
  end

  private

  def create_landlord
    build_landlord(name: email.split("@").first).save!
  end
end
