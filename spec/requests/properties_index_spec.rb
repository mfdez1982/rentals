require "rails_helper"

RSpec.describe "Properties Index Card Grid", type: :request do
  let(:user) { create(:user) }
  let(:landlord) { user.landlord }

  before { sign_in user }

  describe "Card grid rendering" do
    it "displays properties in a responsive grid layout" do
      properties = create_list(:property, 3, landlord: landlord)
      get properties_path
      expect(response).to be_successful
      expect(response.body).to include('class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"')
      properties.each do |property|
        expect(response.body).to include(property.name)
      end
    end

    it "displays empty state when no properties exist" do
      get properties_path
      expect(response).to be_successful
      expect(response.body).to include(I18n.t("properties.no_properties"))
      expect(response.body).to include(I18n.t("properties.no_properties_hint"))
      expect(response.body).to include("btn btn-primary")
    end

    it "renders exactly 0 property cards when no properties" do
      get properties_path
      doc = Nokogiri::HTML(response.body)
      cards = doc.css('[data-testid^="property-card-"]')
      expect(cards.count).to eq(0)
    end

    it "renders exactly 1 property card when 1 property exists" do
      create(:property, landlord: landlord)
      get properties_path
      doc = Nokogiri::HTML(response.body)
      cards = doc.css('[data-testid^="property-card-"]')
      expect(cards.count).to eq(1)
    end

    it "renders exactly 3 property cards when 3 properties exist" do
      create_list(:property, 3, landlord: landlord)
      get properties_path
      doc = Nokogiri::HTML(response.body)
      cards = doc.css('[data-testid^="property-card-"]')
      expect(cards.count).to eq(3)
    end
  end

  describe "Avatar with monogram" do
    it "displays first letter of property name in avatar" do
      property = create(:property, landlord: landlord, name: "Maple Street")
      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      avatar = card.css("div[class*='rounded-full']").first
      expect(avatar.text.strip).to eq("M")
    end

    it "generates deterministic color for same property name" do
      property = create(:property, landlord: landlord, name: "Test Property")
      color_class_1 = get_avatar_color(property)

      # Request again and check color hasn't changed
      get properties_path
      color_class_2 = get_avatar_color(property)

      expect(color_class_1).to eq(color_class_2)
    end

    it "generates deterministic colors from palette" do
      properties = create_list(:property, 6, landlord: landlord) do |property, i|
        property.name = "Property #{i}"
      end

      get properties_path

      properties.each do |property|
        doc = Nokogiri::HTML(response.body)
        card = doc.css("[data-testid='property-card-#{property.id}']").first
        avatar = card.css("div[class*='rounded-full']").first
        classes = avatar.attr("class")

        expect(classes).to match(/bg-(success|warning|error|info|primary|secondary)/)
      end
    end

    private

    def get_avatar_color(property)
      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      avatar = card.css("div[class*='rounded-full']").first
      classes = avatar.attr("class")
      classes.scan(/(bg-\w+)/)[0]&.[](0)
    end
  end

  describe "Status badges" do
    it "displays 'Rented' badge for property with active rental agreement" do
      property = create(:property, landlord: landlord)
      agreement = create(:rental_agreement, property: property,
                        start_date: Date.today - 10.days,
                        end_date: Date.today + 10.days)

      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      badges = card.css("span[class*='badge']")

      expect(badges.map(&:text).join).to include(I18n.t("properties.rented"))
    end

    it "displays 'Available' badge for property without active rental agreement" do
      property = create(:property, landlord: landlord)
      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      badges = card.css("span[class*='badge']")

      expect(badges.map(&:text).join).to include(I18n.t("properties.available"))
    end

    it "displays 'Overdue Payments' badge when property has overdue payments" do
      property = create(:property, landlord: landlord)
      agreement = create(:rental_agreement, property: property,
                        start_date: Date.today - 10.days,
                        end_date: Date.today + 10.days)
      create(:payment, rental_agreement: agreement,
             due_date: Date.today - 5.days, paid_date: nil)

      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      badges = card.css("span[class*='badge']")

      expect(badges.map(&:text).join).to include(I18n.t("properties.overdue_payments"))
    end

    it "displays multiple badges correctly" do
      property = create(:property, landlord: landlord)
      agreement = create(:rental_agreement, property: property,
                        start_date: Date.today - 10.days,
                        end_date: Date.today + 10.days)
      create(:payment, rental_agreement: agreement,
             due_date: Date.today - 5.days, paid_date: nil)

      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      badges = card.css("span[class*='badge']")

      expect(badges.count).to eq(2)
      expect(badges.map(&:text).join).to include(I18n.t("properties.rented"))
      expect(badges.map(&:text).join).to include(I18n.t("properties.overdue_payments"))
    end
  end

  describe "Active rental agreement info" do
    it "displays monthly rent amount when there's an active agreement" do
      property = create(:property, landlord: landlord)
      agreement = create(:rental_agreement, property: property,
                        rent_amount: 1500.00,
                        start_date: Date.today - 10.days,
                        end_date: Date.today + 10.days)

      get properties_path
      expect(response.body).to include("$1,500.00")
    end

    it "displays next payment due date when there's an unpaid payment" do
      property = create(:property, landlord: landlord)
      agreement = create(:rental_agreement, property: property,
                        start_date: Date.today - 10.days,
                        end_date: Date.today + 10.days)
      create(:payment, rental_agreement: agreement,
             due_date: Date.today + 5.days, paid_date: nil)

      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      card_text = card.text

      expect(card_text).to include(I18n.l(Date.today + 5.days, format: :short))
    end

    it "displays days overdue when next payment is overdue" do
      property = create(:property, landlord: landlord)
      agreement = create(:rental_agreement, property: property,
                        start_date: Date.today - 10.days,
                        end_date: Date.today + 10.days)
      create(:payment, rental_agreement: agreement,
             due_date: Date.today - 3.days, paid_date: nil)

      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      card_text = card.text

      expect(card_text).to include("3 days overdue")
    end

    it "does not show rental info when property has no active agreement" do
      property = create(:property, landlord: landlord)
      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      card_text = card.text

      expect(card_text).not_to include(I18n.t("properties.monthly_rent"))
    end
  end

  describe "Navigation and interactions" do
    it "makes entire card clickable to property show page" do
      property = create(:property, landlord: landlord)
      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      link = card.css("a").first

      expect(link.attr("href")).to eq(property_path(property))
    end

    it "includes Turbo Frame target for full-page navigation" do
      property = create(:property, landlord: landlord)
      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      link = card.css("a").first

      expect(link.attr("data-turbo-frame")).to eq("_top")
    end

    it "delete button does not navigate to property" do
      property = create(:property, landlord: landlord)
      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      delete_button = card.css("button.btn-circle").first

      expect(delete_button).to be_present
      # The delete button lives in its own button_to form, outside the card's
      # navigation links, so clicking it never follows the card link.
      expect(delete_button.ancestors("a")).to be_empty
      delete_form = delete_button.ancestors("form").first
      expect(delete_form.attr("action")).to eq(property_path(property))
    end
  end

  describe "Delete functionality" do
    it "includes delete button with confirmation" do
      property = create(:property, landlord: landlord)
      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      delete_form = card.css("form").last

      expect(delete_form.attr("data-turbo-confirm"))
        .to include("Delete \"#{property.name}\"?")
    end

    it "delete button sends DELETE request" do
      property = create(:property, landlord: landlord)
      get properties_path
      doc = Nokogiri::HTML(response.body)
      card = doc.css("[data-testid='property-card-#{property.id}']").first
      delete_form = card.css("form").last

      expect(delete_form.attr("action")).to eq(property_path(property))
      expect(delete_form.attr("method")).to eq("post")
    end

    it "actually deletes property on confirm" do
      property = create(:property, landlord: landlord)
      expect {
        delete property_path(property)
      }.to change(Property, :count).by(-1)

      expect(response).to redirect_to(properties_path)
    end

    it "cannot delete another landlord's property" do
      other_property = create(:property)
      expect {
        delete property_path(other_property)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "Multi-tenancy isolation" do
    it "shows only current landlord's properties" do
      own_property = create(:property, landlord: landlord, name: "My House")
      other_property = create(:property, name: "Other House")

      get properties_path
      expect(response.body).to include(own_property.name)
      expect(response.body).not_to include(other_property.name)
    end

    it "renders cards only for current landlord" do
      own_property = create(:property, landlord: landlord)
      other_property = create(:property)

      get properties_path
      doc = Nokogiri::HTML(response.body)
      cards = doc.css('[data-testid^="property-card-"]')

      expect(cards.count).to eq(1)
      expect(cards.first.attr("data-testid")).to eq("property-card-#{own_property.id}")
    end
  end

  describe "Add property button" do
    it "displays add property button when properties exist" do
      create(:property, landlord: landlord)
      get properties_path
      expect(response.body).to include("btn btn-primary")
      expect(response.body).to include(I18n.t("properties.add_property"))
    end

    it "displays add property button when no properties exist" do
      get properties_path
      expect(response.body).to include("btn btn-primary")
      expect(response.body).to include(I18n.t("properties.add_property"))
    end

    it "modal appears with property form" do
      get properties_path
      doc = Nokogiri::HTML(response.body)
      modal = doc.css("dialog.modal").first
      form = modal.css("form").first

      expect(form).to be_present
    end
  end
end
