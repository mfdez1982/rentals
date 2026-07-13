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
end
