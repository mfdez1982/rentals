class Landlord < ApplicationRecord
  belongs_to :user
  has_many :properties, dependent: :destroy
  has_many :notes, dependent: :destroy

  enum :plan, { free: 0, pro: 1, premium: 2 }, default: :free

  validates :name, presence: true

  # Identifies this landlord as a Flipper actor, so features can be checked
  # against `current_landlord` (e.g. Flipper.enabled?(:tax_report, current_landlord)).
  def flipper_id
    "Landlord;#{id}"
  end

  def multi_property?
    Flipper.enabled?(:multi_property, self)
  end

  def property_limit_reached?
    !multi_property? && properties.count >= 1
  end
end
