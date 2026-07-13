module AgreementShowLoadable
  extend ActiveSupport::Concern

  # Rebuilds every ivar app/views/rental_agreements/show.html.erb needs, so
  # PaymentsController can re-render that template directly on a validation
  # failure without losing the section frame the failing form lives in.
  def load_agreement_show_data
    @payments = @agreement.payments.order(due_date: :asc).to_a
    @notes = @agreement.notes.active.order(due_date: :asc, created_at: :desc)
    @agreement_tenants = @agreement.agreement_tenants.order(created_at: :desc)
  end
end
