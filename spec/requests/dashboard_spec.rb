require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /" do
    context "when not logged in" do
      it "redirects to login" do
        get root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when logged in" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "renders the dashboard" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
