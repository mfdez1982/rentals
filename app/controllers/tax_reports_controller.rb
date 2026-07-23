class TaxReportsController < ApplicationController
  before_action :set_property
  before_action :set_tax_report, only: [:show, :edit, :update, :destroy]
  before_action -> { redirect_unless_turbo_frame_request(property_tax_reports_path(@property)) }, only: [:edit]

  def index
    load_index_data
  end

  def create
    year = params[:year].to_i
    unless year.positive?
      redirect_to property_tax_reports_path(@property), alert: t("tax_report.invalid_year") and return
    end

    TaxReportGenerator.new(@property, year).create_report!
    redirect_to property_tax_reports_path(@property), notice: t("tax_report.generated")
  end

  def show
  end

  def edit
  end

  def update
    if @tax_report.update(tax_report_params)
      redirect_to property_tax_reports_path(@property), notice: t("tax_report.renamed")
    else
      load_index_data
      @editing_tax_report = @tax_report
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @tax_report.destroy
    redirect_to property_tax_reports_path(@property), notice: t("tax_report.deleted")
  end

  private

  def load_index_data
    @tax_reports = @property.tax_reports.order(year: :desc, created_at: :desc)
    @year = params[:year].to_i.positive? ? params[:year].to_i : Date.today.year
    start_year = [@property.earliest_tax_year, Date.today.year].min
    @year_options = (start_year..Date.today.year + 1).to_a.reverse
    @collectable_deductible_expenses = @property.expenses.collectable.deductible
      .where(date: Date.new(@year, 1, 1)..Date.new(@year, 12, 31))
      .order(:date)
  end

  def set_tax_report
    @tax_report = @property.tax_reports.find(params[:id])
  end

  def tax_report_params
    params.require(:tax_report).permit(:name)
  end
end
