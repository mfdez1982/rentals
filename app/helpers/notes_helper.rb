module NotesHelper
  def related_to_label(note)
    case note.noteable_type
    when "Property"
      note.noteable&.name || "—"
    when "RentalAgreement"
      agreement = note.noteable
      if agreement&.property
        "#{agreement.property.name} > #{l(agreement.start_date, format: :short)}"
      else
        "—"
      end
    else
      t("notes.scopes.general")
    end
  end

  def notes_by_scope(notes)
    grouped = {}

    # General notes (no noteable)
    general_notes = notes.where(noteable_type: nil, noteable_id: nil)
    grouped[t("notes.scopes.general")] = general_notes if general_notes.any?

    # Notes grouped by property
    properties = Property.where(landlord_id: current_landlord.id).includes(:notes)
    properties.each do |property|
      property_notes = notes.where(noteable_type: "Property", noteable_id: property.id)
      if property_notes.any?
        grouped[t("notes.scopes.property", name: property.name)] = property_notes
      end

      # Rental agreement notes within this property
      property.rental_agreements.includes(:notes).each do |agreement|
        agreement_notes = notes.where(noteable_type: "RentalAgreement", noteable_id: agreement.id)
        if agreement_notes.any?
          grouped[t("notes.scopes.agreement", start_date: l(agreement.start_date, format: :short))] = agreement_notes
        end
      end
    end

    grouped
  end
end
