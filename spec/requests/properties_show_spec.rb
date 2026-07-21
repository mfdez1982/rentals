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

  describe "GET /properties/:id/tax_report" do
    it "renders the report for the requested year" do
      create(:rental_agreement, property: property,
             start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31))
      get tax_report_property_path(property, year: 2025)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="2025" selected')
    end

    it "falls back to the current year when the year param is invalid" do
      get tax_report_property_path(property, year: "garbage")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(value="#{Date.today.year}" selected))
    end

    it "cannot render another landlord's tax report" do
      other = create(:property)
      expect { get tax_report_property_path(other) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
