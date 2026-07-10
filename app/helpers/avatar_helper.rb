module AvatarHelper
  # Deterministic color palette based on property name hash
  # Returns a Tailwind CSS color class and a hex value for styling
  AVATAR_COLORS = [
    { class: "bg-success", hex: "#22c55e" },
    { class: "bg-warning", hex: "#eab308" },
    { class: "bg-error", hex: "#ef4444" },
    { class: "bg-info", hex: "#06b6d4" },
    { class: "bg-primary", hex: "#10b981" },
    { class: "bg-secondary", hex: "#a78bfa" }
  ].freeze

  def avatar_for_property(property)
    {
      initials: property.name.first.upcase,
      color_class: color_for_property(property),
      color_hex: color_hex_for_property(property)
    }
  end

  private

  def color_for_property(property)
    AVATAR_COLORS[property_name_hash(property.name) % AVATAR_COLORS.length][:class]
  end

  def color_hex_for_property(property)
    AVATAR_COLORS[property_name_hash(property.name) % AVATAR_COLORS.length][:hex]
  end

  def property_name_hash(name)
    name.downcase.hash.abs
  end
end
