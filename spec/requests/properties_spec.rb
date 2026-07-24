require "rails_helper"

RSpec.describe "Properties", type: :request do
  let(:user) { create(:user) }
  let(:landlord) { user.landlord }

  before { sign_in user }

  describe "GET /properties" do
    it "shows only the current landlord's properties" do
      own = create(:property, landlord: landlord, name: "My House")
      _other = create(:property, name: "Other House")
      get properties_path
      expect(response.body).to include("My House")
      expect(response.body).not_to include("Other House")
    end
  end

  describe "POST /properties" do
    it "creates a property and redirects" do
      post properties_path, params: { property: { name: "New Place", rented: false } }
      expect(response).to redirect_to(properties_path)
      expect(landlord.properties.count).to eq(1)
    end

    it "renders index with errors on blank name" do
      post properties_path, params: { property: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "free plan property limit" do
      before do
        Flipper.enable_group(:multi_property, :pro_and_up)
        create(:property, landlord: landlord)
      end
      after { Flipper.remove(:multi_property) }

      it "blocks a second property for a free landlord" do
        post properties_path, params: { property: { name: "Second Place" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(landlord.properties.count).to eq(1)
      end

      it "allows a second property for a pro landlord" do
        landlord.update!(plan: :pro)
        post properties_path, params: { property: { name: "Second Place" } }
        expect(response).to redirect_to(properties_path)
        expect(landlord.properties.count).to eq(2)
      end

      it "allows a second property for a premium landlord" do
        landlord.update!(plan: :premium)
        post properties_path, params: { property: { name: "Second Place" } }
        expect(response).to redirect_to(properties_path)
        expect(landlord.properties.count).to eq(2)
      end
    end
  end

  describe "PATCH /properties/:id" do
    let(:property) { create(:property, landlord: landlord) }

    it "updates and redirects" do
      patch property_path(property), params: { property: { name: "Updated" } }
      expect(response).to redirect_to(properties_path)
      expect(property.reload.name).to eq("Updated")
    end

    it "cannot update another landlord's property" do
      other = create(:property)
      expect { patch property_path(other), params: { property: { name: "Hack" } } }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE /properties/:id" do
    let(:property) { create(:property, landlord: landlord) }

    it "destroys the property" do
      delete property_path(property)
      expect(landlord.properties.reload).not_to include(property)
    end

    it "cannot delete another landlord's property" do
      other = create(:property)
      expect { delete property_path(other) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
