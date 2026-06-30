class Landlord < ApplicationRecord
  belongs_to :user
  has_many :properties, dependent: :destroy

  validates :name, presence: true
end
