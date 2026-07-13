require "rails_helper"

RSpec.describe "Registrations claiming a tenant invitation", type: :request do
  let(:valid_params) do
    {
      email: "new@example.com",
      password: "password123",
      password_confirmation: "password123"
    }
  end

  describe "signing up with a valid, unexpired invitation token" do
    it "claims the invitation and still creates a Landlord for the new user" do
      invitation = create(:agreement_tenant, invited_email: "new@example.com")

      expect {
        post user_registration_path, params: { user: valid_params.merge(invitation_token: invitation.invitation_token) }
      }.to change(User, :count).by(1)

      new_user = User.find_by(email: "new@example.com")
      expect(new_user).to be_present
      expect(new_user.landlord).to be_present

      invitation.reload
      expect(invitation).to be_accepted
      expect(invitation.user).to eq(new_user)
    end
  end

  describe "signing up with an expired invitation token" do
    it "creates the user but does not claim the invitation" do
      invitation = create(:agreement_tenant, :expired, invited_email: "new@example.com")

      expect {
        post user_registration_path, params: { user: valid_params.merge(invitation_token: invitation.invitation_token) }
      }.to change(User, :count).by(1)

      expect(invitation.reload).to be_pending
      expect(invitation.user).to be_nil
    end
  end

  describe "signing up with no invitation token" do
    it "registers normally without touching any invitations" do
      other_invitation = create(:agreement_tenant, invited_email: "someone-else@example.com")

      expect {
        post user_registration_path, params: { user: valid_params }
      }.to change(User, :count).by(1)

      expect(other_invitation.reload).to be_pending
    end
  end
end
