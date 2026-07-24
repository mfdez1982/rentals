require "rails_helper"

RSpec.describe "TaxReports", type: :request do
  let(:user) { create(:user) }
  let(:landlord) { user.landlord }
  let(:property) { create(:property, landlord: landlord) }

  before do
    Flipper.enable_group(:tax_report, :pro_and_up)
    landlord.update!(plan: :premium)
    sign_in user
  end

  after { Flipper.remove(:tax_report) }

  describe "GET /properties/:property_id/tax_reports" do
    it "lists saved reports and the generate control" do
      report = create(:tax_report, property: property, year: 2024)
      get property_tax_reports_path(property)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("2024")
      expect(response.body).to include(I18n.t("tax_report.generate"))
    end

    it "cannot list another landlord's property reports" do
      other_property = create(:property)
      expect {
        get property_tax_reports_path(other_property)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST /properties/:property_id/tax_reports" do
    it "generates and persists a snapshot for the chosen year" do
      create(:rental_agreement, property: property,
             start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31))
      create(:expense, property: property, date: Date.new(2025, 3, 1), amount: 100)

      expect {
        post property_tax_reports_path(property), params: { year: 2025 }
      }.to change { property.tax_reports.count }.by(1)

      report = property.tax_reports.last
      expect(report.year).to eq(2025)
      expect(report.expense_lines).to be_present
      expect(response).to redirect_to(property_tax_reports_path(property))
    end

    it "rejects an invalid year" do
      expect {
        post property_tax_reports_path(property), params: { year: 0 }
      }.not_to change { property.tax_reports.count }
      expect(flash[:alert]).to be_present
    end
  end

  describe "GET /properties/:property_id/tax_reports/:id" do
    it "opens a saved report" do
      report = create(:tax_report, property: property)
      get property_tax_report_path(property, report)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(property.name)
    end
  end

  describe "GET /properties/:property_id/tax_reports/:id/edit" do
    it "renders the rename form for a turbo frame request" do
      report = create(:tax_report, property: property)
      get edit_property_tax_report_path(property, report),
          headers: { "Turbo-Frame" => "tax_report_edit_frame" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("tax_report.edit_name"))
    end
  end

  describe "PATCH /properties/:property_id/tax_reports/:id" do
    it "updates the name without touching the snapshot figures" do
      report = create(:tax_report, property: property, active_rental_days: 214)
      patch property_tax_report_path(property, report), params: { tax_report: { name: "My filing" } }
      expect(response).to redirect_to(property_tax_reports_path(property))
      expect(report.reload.name).to eq("My filing")
      expect(report.active_rental_days).to eq(214)
    end
  end

  describe "DELETE /properties/:property_id/tax_reports/:id" do
    it "deletes a saved report" do
      report = create(:tax_report, property: property)
      expect {
        delete property_tax_report_path(property, report)
      }.to change { property.tax_reports.count }.by(-1)
      expect(response).to redirect_to(property_tax_reports_path(property))
    end
  end

  context "when the landlord is on the free plan" do
    before { landlord.update!(plan: :free) }

    it "blocks generating a new report" do
      expect {
        post property_tax_reports_path(property), params: { year: 2025 }
      }.not_to change { property.tax_reports.count }
      expect(response).to redirect_to(property_tax_reports_path(property))
      expect(flash[:alert]).to eq(I18n.t("tax_report.errors.plan_limit"))
    end

    it "blocks opening a saved report" do
      report = create(:tax_report, property: property)
      get property_tax_report_path(property, report)
      expect(response).to redirect_to(property_tax_reports_path(property))
    end

    it "blocks renaming a saved report" do
      report = create(:tax_report, property: property)
      patch property_tax_report_path(property, report), params: { tax_report: { name: "My filing" } }
      expect(response).to redirect_to(property_tax_reports_path(property))
      expect(report.reload.name).to be_nil
    end

    it "blocks deleting a saved report" do
      report = create(:tax_report, property: property)
      expect {
        delete property_tax_report_path(property, report)
      }.not_to change { property.tax_reports.count }
      expect(response).to redirect_to(property_tax_reports_path(property))
    end
  end
end
