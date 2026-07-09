class Landlord < ApplicationRecord
  belongs_to :user
  has_many :properties, dependent: :destroy
  has_many :notes, as: :noteable, dependent: :destroy

  validates :name, presence: true
end
