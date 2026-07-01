class PropertiesController < ApplicationController
  before_action :set_property, only: [:show, :edit, :update, :destroy]

  def index
    @properties = current_landlord.properties
    @new_property = Property.new
  end

  def show
    @agreements = @property.rental_agreements.sorted
    @new_agreement = @property.rental_agreements.build
  end

  def create
    @new_property = current_landlord.properties.build(property_params)
    if @new_property.save
      redirect_to properties_path
    else
      @properties = current_landlord.properties.where.not(id: nil)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @property.update(property_params)
      redirect_to properties_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @property.destroy
    redirect_to properties_path
  end

  private

  def set_property
    @property = current_landlord.properties.find(params[:id])
  end

  def property_params
    params.require(:property).permit(:name)
  end
end
