class PaymentsController < ApplicationController
  include AgreementShowLoadable

  before_action :set_property
  before_action :set_agreement
  before_action :set_payment, only: [:edit, :update, :destroy]
  before_action -> { redirect_unless_turbo_frame_request(property_rental_agreement_path(@property, @agreement)) }, only: [:edit]

  def create_recurring
    start_date = Date.parse(params[:start_date])
    count = [[params[:count].to_i, 1].max, 12].min
    amount = params[:amount]

    ActiveRecord::Base.transaction do
      count.times do |i|
        @agreement.payments.create!(
          due_date: start_date >> i,
          amount: amount
        )
      end
    end

    redirect_to property_rental_agreement_path(@property, @agreement)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to property_rental_agreement_path(@property, @agreement),
      alert: t("payments.create_error", error: e.message)
  rescue ArgumentError, TypeError
    redirect_to property_rental_agreement_path(@property, @agreement),
      alert: t("payments.invalid_start_date")
  end

  def edit
  end

  def update
    if @payment.update(payment_params)
      redirect_to property_rental_agreement_path(@property, @agreement)
    else
      load_agreement_show_data
      @editing_payment = @payment
      render template: "rental_agreements/show", status: :unprocessable_entity
    end
  end

  def destroy
    @payment.destroy
    redirect_to property_rental_agreement_path(@property, @agreement)
  end

  private

  def set_payment
    @payment = @agreement.payments.find(params[:id])
  end

  def payment_params
    params.require(:payment).permit(:due_date, :paid_date, :amount)
  end
end
