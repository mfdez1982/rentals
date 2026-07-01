class Property < ApplicationRecord
  belongs_to :landlord
  has_many :rental_agreements, dependent: :destroy

  validates :name, presence: true

  def rented?
    rental_agreements.active.exists?
  end
end
