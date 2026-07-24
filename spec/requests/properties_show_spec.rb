require "rails_helper"

RSpec.describe "Properties show & tax report", type: :request do
  let(:user) { create(:user) }
  let(:landlord) { user.landlord }
  let(:property) { create(:property, landlord: landlord) }

  before { sign_in user }

  describe "GET /properties/:id" do
    it "renders the property page with all sections" do
      agreement = create(:rental_agreement, property: property,
                         start_date: 6.months.ago.to_date, end_date: 6.months.from_now.to_date)
      create(:expense, property: property)
      create(:note, landlord: landlord, noteable: property, title: "Fix boiler")

      get property_path(property)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(property.name)
      expect(response.body).to include("agreements_property_#{property.id}")
      expect(response.body).to include("expenses_property_#{property.id}")
      expect(response.body).to include("Fix boiler")
    end

    it "shows notes attached to the property's agreements" do
      agreement = create(:rental_agreement, property: property)
      create(:note, landlord: landlord, noteable: agreement, title: "Deposit pending")

      get property_path(property)
      expect(response.body).to include("Deposit pending")
    end

    it "targets the Recollect link at _top so it escapes the expenses frame" do
      create(:expense, property: property, collectable: true,
             period_start: "2026-03-01", period_end: "2026-03-31")

      get property_path(property)

      link = Nokogiri::HTML(response.body)
        .at_css("a[href='#{new_property_expense_recollection_path(property, property.expenses.first)}']")
      expect(link).to be_present
      expect(link["data-turbo-frame"]).to eq("_top")
    end

    it "cannot show another landlord's property" do
      other = create(:property)
      expect { get property_path(other) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context "when downgraded to free with multiple properties" do
      it "still shows the oldest property but locks the rest" do
        first = create(:property, landlord: landlord, created_at: 2.days.ago)
        second = create(:property, landlord: landlord, created_at: 1.day.ago)

        get property_path(first)
        expect(response).to have_http_status(:ok)

        get property_path(second)
        expect(response).to redirect_to(properties_path)
        expect(flash[:alert]).to eq(I18n.t("properties.errors.locked"))
      end

      it "blocks reaching a locked property's nested resources directly" do
        create(:property, landlord: landlord, created_at: 2.days.ago)
        locked = create(:property, landlord: landlord, created_at: 1.day.ago)
        agreement = create(:rental_agreement, property: locked)

        get property_rental_agreement_path(locked, agreement)
        expect(response).to redirect_to(properties_path)
      end
    end
  end

  describe "GET /properties/:id/edit" do
    it "redirects to the property when not a turbo frame request" do
      get edit_property_path(property)
      expect(response).to redirect_to(property_path(property))
    end

    it "renders inside a turbo frame request" do
      get edit_property_path(property), headers: { "Turbo-Frame" => "property_edit_frame" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /properties/:id (inline)" do
    it "redirects to the property page on inline update" do
      patch property_path(property), params: { inline: "true", property: { name: "Renamed" } }
      expect(response).to redirect_to(property_path(property))
      expect(property.reload.name).to eq("Renamed")
    end

    it "re-renders the property page with errors on invalid inline update" do
      patch property_path(property), params: { inline: "true", property: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /properties/:id/tax_reports (generate control)" do
    it "renders the year dropdown + Generate button" do
      create(:rental_agreement, property: property,
             start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31))
      get property_tax_reports_path(property, year: 2025)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="2025" selected')
      expect(response.body).to include(I18n.t("tax_report.generate"))
    end

    it "falls back to the current year when the year param is invalid" do
      get property_tax_reports_path(property, year: "garbage")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(value="#{Date.today.year}" selected))
    end

    it "does not show the validation warning when no expense is both collectable and deductible" do
      create(:expense, property: property, date: Date.new(2025, 5, 1), deductible: true, collectable: false)

      get property_tax_reports_path(property, year: 2025)
      expect(response.body).not_to include(I18n.t("tax_report.validate_expenses_warning"))
    end

    it "lists offending expenses when one is both collectable and deductible in the selected year" do
      create(:expense, :collectable, property: property, deductible: true,
             date: Date.new(2025, 6, 15), description: "Water bill")

      get property_tax_reports_path(property, year: 2025)
      expect(response.body).to include(I18n.t("tax_report.validate_expenses_warning"))
      expect(response.body).to include("Water bill")
    end

    it "does not flag a collectable+deductible expense from a different year" do
      create(:expense, :collectable, property: property, deductible: true,
             date: Date.new(2024, 6, 15), description: "Old water bill")

      get property_tax_reports_path(property, year: 2025)
      expect(response.body).not_to include(I18n.t("tax_report.validate_expenses_warning"))
    end
  end
end
