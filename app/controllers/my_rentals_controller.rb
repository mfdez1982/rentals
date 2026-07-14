class MyRentalsController < ApplicationController
  def index
    @agreements = current_user.tenant_rental_agreements.includes(:property).order(start_date: :desc)
    @pending_recollection_counts = Recollection.pending
      .joins(:agreement_tenant)
      .where(agreement_tenants: { user_id: current_user.id })
      .group(:rental_agreement_id)
      .count
  end

  def show
    @agreement = current_user.tenant_rental_agreements.find(params[:id])
    @property = @agreement.property
    @payments = @agreement.payments.order(due_date: :asc)
    @recollections = @agreement.recollections
      .joins(:agreement_tenant)
      .where(agreement_tenants: { user_id: current_user.id })
      .includes(:expense)
      .order(due_date: :asc, created_at: :asc)
  end
end
