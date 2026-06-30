class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  has_one :landlord, dependent: :destroy

  enum :role, { landlord: 0, admin: 1 }, default: :landlord

  after_create :create_landlord, if: :landlord?

  private

  def create_landlord
    build_landlord(name: email.split("@").first).save!
  end
end
