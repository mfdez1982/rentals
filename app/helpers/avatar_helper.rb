module AvatarHelper
  # Deterministic color palette based on property name hash
  AVATAR_COLORS = [
    "bg-success",
    "bg-warning",
    "bg-error",
    "bg-info",
    "bg-primary",
    "bg-secondary"
  ].freeze

  def avatar_for_property(property)
    {
      initials: property.name.first.upcase,
      color_class: AVATAR_COLORS[property_name_hash(property.name) % AVATAR_COLORS.length]
    }
  end

  private

  # Stable across processes/restarts, unlike String#hash (randomly seeded per process).
  def property_name_hash(name)
    Digest::MD5.hexdigest(name.downcase).to_i(16)
  end
end
