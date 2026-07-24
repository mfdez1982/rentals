class PropertiesController < ApplicationController
  include PropertyShowLoadable

  before_action :set_property, only: [:show, :edit, :update, :destroy]
  before_action :ensure_property_accessible, only: [:show, :destroy]
  before_action -> { redirect_unless_turbo_frame_request(property_path(@property)) }, only: [:edit]

  def index
    @properties = current_landlord.properties.includes(rental_agreements: :payments)
    @new_property = Property.new
  end

  def show
    load_property_show_data
  end

  def create
    @new_property = current_landlord.properties.build(property_params)
    if current_landlord.property_limit_reached?
      @new_property.errors.add(:base, t("properties.errors.plan_limit"))
      @properties = current_landlord.properties.reload
      render :index, status: :unprocessable_entity
    elsif @new_property.save
      redirect_to properties_path
    else
      @properties = current_landlord.properties.reload
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @property.update(property_params)
      redirect_to params[:inline] ? property_path(@property) : properties_path
    elsif params[:inline]
      load_property_show_data
      @editing_property = @property
      render template: "properties/show", status: :unprocessable_entity
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

  def ensure_property_accessible
    redirect_to properties_path, alert: t("properties.errors.locked") if current_landlord.property_locked?(@property)
  end

  def property_params
    params.require(:property).permit(:name)
  end
end
