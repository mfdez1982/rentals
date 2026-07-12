module PropertyShowLoadable
  extend ActiveSupport::Concern

  # Rebuilds every ivar app/views/properties/show.html.erb needs, so any
  # controller (expenses, rental_agreements, notes) can re-render that
  # template directly on a validation failure without losing the section
  # frame the failing form lives in.
  def load_property_show_data
    @agreements = @property.rental_agreements.sorted
    @new_agreement = @property.rental_agreements.build
    @expenses = @property.expenses.order(date: :desc)
    @new_expense = @property.expenses.build
    @property_notes = @property.notes.active.order(due_date: :asc, created_at: :desc)
    @agreement_notes = Note.where(noteable_type: "RentalAgreement", noteable_id: @property.rental_agreements.pluck(:id)).active.order(due_date: :asc, created_at: :desc)
    @year = Date.today.year
    @report = TaxReportGenerator.new(@property, @year).generate
    start_year = [@property.earliest_tax_year, Date.today.year].min
    @year_options = (start_year..Date.today.year + 1).to_a.reverse
  end
end
