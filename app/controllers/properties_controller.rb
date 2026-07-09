class PropertiesController < ApplicationController
  before_action :set_property, only: [:show, :edit, :update, :destroy, :tax_report]
  before_action -> { redirect_unless_turbo_frame_request(property_path(@property)) }, only: [:edit]

  def index
    @properties = current_landlord.properties
    @new_property = Property.new
  end

  def show
    @agreements = @property.rental_agreements.sorted
    @new_agreement = @property.rental_agreements.build
    @expenses = @property.expenses.order(date: :desc)
    @new_expense = @property.expenses.build
    @property_notes = @property.notes.active.order(due_date: :asc, created_at: :desc)
    @agreement_notes = Note.where(noteable_type: "RentalAgreement", noteable_id: @property.rental_agreements.pluck(:id)).active.order(due_date: :asc, created_at: :desc)
  end

  def tax_report
    @year = params[:year].to_i.positive? ? params[:year].to_i : Date.today.year
    @report = TaxReportGenerator.new(@property, @year).generate
    start_year = [@property.earliest_tax_year, Date.today.year].min
    @year_options = (start_year..Date.today.year + 1).to_a.reverse
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
      redirect_to params[:inline] ? property_path(@property) : properties_path
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
