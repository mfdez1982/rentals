require "rails_helper"

RSpec.describe "Landing redirects for root path", type: :request do
  describe "GET /" do
    it "redirects a tenant-only user (no properties, an accepted tenancy elsewhere) to my_rentals" do
      user = create(:user)
      other_agreement = create(:rental_agreement)
      create(:agreement_tenant, :accepted, rental_agreement: other_agreement, user: user, invited_email: user.email)

      sign_in user
      get root_path

      expect(response).to redirect_to(my_rentals_path)
    end

    it "renders the property dashboard for a landlord with a property (no redirect)" do
      user = create(:user)
      create(:property, landlord: user.landlord)

      sign_in user
      get root_path

      expect(response).to have_http_status(:ok)
    end

    it "redirects an admin to the backoffice root" do
      admin = create(:user, role: :admin)

      sign_in admin
      get root_path

      expect(response).to redirect_to(backoffice_root_path)
    end
  end
end
