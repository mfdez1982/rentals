require "rails_helper"

RSpec.describe "RentalAgreements", type: :request do
  let(:user) { create(:user) }
  let(:landlord) { user.landlord }
  let(:property) { create(:property, landlord: landlord) }
  let(:agreement) do
    create(:rental_agreement, property: property,
           start_date: 6.months.ago.to_date, end_date: 6.months.from_now.to_date)
  end

  before { sign_in user }

  describe "GET /properties/:property_id/rental_agreements/:id" do
    it "renders the agreement page" do
      get property_rental_agreement_path(property, agreement)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(number_to_currency_amount(agreement.rent_amount))
    end

    it "cannot show another landlord's agreement" do
      other = create(:rental_agreement)
      expect {
        get property_rental_agreement_path(other.property, other)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "cannot reach an agreement through a property it does not belong to" do
      other_agreement = create(:rental_agreement)
      expect {
        get property_rental_agreement_path(property, other_agreement)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET /properties/:property_id/rental_agreements/new" do
    it "redirects to the property when not a turbo frame request" do
      get new_property_rental_agreement_path(property)
      expect(response).to redirect_to(property_path(property))
    end

    it "renders inside a turbo frame request" do
      get new_property_rental_agreement_path(property),
          headers: { "Turbo-Frame" => "agreements_property_#{property.id}" }
      expect(response).to have_http_status(:ok)
    end

    it "pre-fills start date and rent when renewing from a source agreement" do
      get new_property_rental_agreement_path(property, source_id: agreement.id),
          headers: { "Turbo-Frame" => "agreements_property_#{property.id}" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include((agreement.end_date + 1.day).iso8601)
      expect(response.body).to include(agreement.rent_amount.to_s)
    end
  end

  describe "POST /properties/:property_id/rental_agreements" do
    let(:valid_params) do
      { rental_agreement: {
        start_date: 2.years.from_now.to_date.iso8601,
        end_date: 3.years.from_now.to_date.iso8601,
        rent_amount: "950.00"
      } }
    end

    it "creates an agreement and redirects to the property" do
      expect {
        post property_rental_agreements_path(property), params: valid_params
      }.to change(property.rental_agreements, :count).by(1)
      expect(response).to redirect_to(property_path(property))
    end

    it "rejects an agreement overlapping an existing one" do
      agreement # create the existing one
      post property_rental_agreements_path(property), params: {
        rental_agreement: {
          start_date: Date.today.iso8601,
          end_date: 1.year.from_now.to_date.iso8601,
          rent_amount: "500"
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("rental_agreements.errors.overlapping"))
      expect(property.rental_agreements.count).to eq(1)
    end

    it "rejects end date before start date" do
      post property_rental_agreements_path(property), params: {
        rental_agreement: {
          start_date: Date.today.iso8601,
          end_date: 1.day.ago.to_date.iso8601,
          rent_amount: "500"
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("rental_agreements.errors.end_date_after_start"))
    end

    it "cannot create an agreement on another landlord's property" do
      other_property = create(:property)
      expect {
        post property_rental_agreements_path(other_property), params: valid_params
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET /properties/:property_id/rental_agreements/:id/edit" do
    it "redirects to the agreement when not a turbo frame request" do
      get edit_property_rental_agreement_path(property, agreement)
      expect(response).to redirect_to(property_rental_agreement_path(property, agreement))
    end

    it "renders inside a turbo frame request" do
      get edit_property_rental_agreement_path(property, agreement),
          headers: { "Turbo-Frame" => "agreement_edit_frame" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /properties/:property_id/rental_agreements/:id" do
    it "updates and redirects to the property (non-inline)" do
      patch property_rental_agreement_path(property, agreement), params: {
        rental_agreement: { rent_amount: "1234.00" }
      }
      expect(response).to redirect_to(property_path(property))
      expect(agreement.reload.rent_amount).to eq(1234.00)
    end

    it "updates and redirects to the agreement when inline" do
      patch property_rental_agreement_path(property, agreement), params: {
        inline: "true",
        rental_agreement: { rent_amount: "1234.00" }
      }
      expect(response).to redirect_to(property_rental_agreement_path(property, agreement))
    end

    it "allows saving an agreement with unchanged dates (overlap check excludes self)" do
      patch property_rental_agreement_path(property, agreement), params: {
        rental_agreement: {
          start_date: agreement.start_date.iso8601,
          end_date: agreement.end_date.iso8601,
          rent_amount: "999.00"
        }
      }
      expect(response).to redirect_to(property_path(property))
      expect(agreement.reload.rent_amount).to eq(999.00)
    end

    it "re-renders the agreement page with errors when inline update fails" do
      patch property_rental_agreement_path(property, agreement), params: {
        inline: "true",
        rental_agreement: { rent_amount: "-5" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "cannot update another landlord's agreement" do
      other = create(:rental_agreement)
      expect {
        patch property_rental_agreement_path(other.property, other), params: {
          rental_agreement: { rent_amount: "1" }
        }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE /properties/:property_id/rental_agreements/:id" do
    it "destroys the agreement and redirects to the property" do
      agreement
      expect {
        delete property_rental_agreement_path(property, agreement)
      }.to change(property.rental_agreements, :count).by(-1)
      expect(response).to redirect_to(property_path(property))
    end

    it "destroys dependent payments" do
      create(:payment, rental_agreement: agreement)
      expect {
        delete property_rental_agreement_path(property, agreement)
      }.to change(Payment, :count).by(-1)
    end

    it "cannot destroy another landlord's agreement" do
      other = create(:rental_agreement)
      expect {
        delete property_rental_agreement_path(other.property, other)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  # Formats the amount the way number_to_currency renders it in views, without
  # depending on the app's currency locale settings.
  def number_to_currency_amount(amount)
    ActiveSupport::NumberHelper.number_to_currency(amount)
  end
end
