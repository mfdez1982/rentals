class MyRentalsController < ApplicationController
  def index
    @agreements = current_user.tenant_rental_agreements.includes(:property).order(start_date: :desc)
  end

  def show
    @agreement = current_user.tenant_rental_agreements.find(params[:id])
    @property = @agreement.property
    @payments = @agreement.payments.order(due_date: :asc)
  end
end
