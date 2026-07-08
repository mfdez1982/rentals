class PaymentsController < ApplicationController
  before_action :set_property
  before_action :set_agreement
  before_action :set_payment, only: [:edit, :update, :destroy]
  before_action -> { redirect_unless_turbo_frame_request(property_rental_agreement_path(@property, @agreement)) }, only: [:edit]

  def create_recurring
    start_date = Date.parse(params[:start_date])
    count = [[params[:count].to_i, 1].max, 12].min
    amount = params[:amount]

    count.times do |i|
      @agreement.payments.create!(
        due_date: start_date >> i,
        amount: amount
      )
    end

    redirect_to property_rental_agreement_path(@property, @agreement)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to property_rental_agreement_path(@property, @agreement),
      alert: t("payments.create_error", error: e.message)
  end

  def edit
  end

  def update
    if @payment.update(payment_params)
      redirect_to property_rental_agreement_path(@property, @agreement)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @payment.destroy
    redirect_to property_rental_agreement_path(@property, @agreement)
  end

  private

  def set_property
    @property = current_landlord.properties.find(params[:property_id])
  end

  def set_agreement
    @agreement = @property.rental_agreements.find(params[:rental_agreement_id])
  end

  def set_payment
    @payment = @agreement.payments.find(params[:id])
  end

  def payment_params
    params.require(:payment).permit(:due_date, :paid_date, :amount)
  end
end
