class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  has_one :landlord, dependent: :destroy

  after_create :create_landlord

  private

  def create_landlord
    build_landlord(name: email.split("@").first).save!
  end
end
