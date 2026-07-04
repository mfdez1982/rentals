class RentalAgreementsController < ApplicationController
  before_action :set_property
  before_action :set_agreement, only: [:show, :edit, :update, :destroy]

  def show
    @payments = @agreement.payments.order(due_date: :asc).to_a
  end

  def new
    @agreement = @property.rental_agreements.build
    if params[:source_id]
      source = @property.rental_agreements.find(params[:source_id])
      @agreement.start_date = source.end_date + 1.day
      @agreement.rent_amount = source.rent_amount
    end
    @agreements = @property.rental_agreements.sorted
  end

  def create
    @agreement = @property.rental_agreements.build(agreement_params)
    if @agreement.save
      redirect_to property_path(@property)
    else
      @agreements = @property.rental_agreements.sorted
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @agreement.update(agreement_params)
      redirect_to params[:inline] ? property_rental_agreement_path(@property, @agreement) : property_path(@property)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @agreement.destroy
    redirect_to property_path(@property)
  end

  private

  def set_property
    @property = current_landlord.properties.find(params[:property_id])
  end

  def set_agreement
    @agreement = @property.rental_agreements.find(params[:id])
  end

  def agreement_params
    params.require(:rental_agreement).permit(:start_date, :end_date, :rent_amount)
  end
end
