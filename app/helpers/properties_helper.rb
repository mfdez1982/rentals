module PropertiesHelper
  # A property is read-only when the landlord's plan has locked it (a downgraded
  # landlord keeps view access to over-limit properties, but can't modify them).
  def property_read_only?(property)
    current_landlord&.property_locked?(property) || false
  end
end
