class Property < ApplicationRecord
  belongs_to :landlord

  validates :name, presence: true
end
