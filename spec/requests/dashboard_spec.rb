require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /" do
    context "when not logged in" do
      it "redirects to landing" do
        get root_path
        expect(response).to redirect_to(landing_path)
      end
    end

    context "when logged in" do
      before { sign_in create(:user) }

      it "renders the dashboard" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
