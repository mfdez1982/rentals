require "rails_helper"

RSpec.describe "TenantInvitations", type: :request do
  let(:user) { create(:user, email: "tenant@example.com") }
  let(:landlord_user) { create(:user) }
  let(:property) { create(:property, landlord: landlord_user.landlord) }
  let(:agreement) { create(:rental_agreement, property: property) }

  before { sign_in user }

  describe "POST /tenant_invitations/:id/accept" do
    it "accepts a pending invitation matching the signed-in user's email" do
      invitation = create(:agreement_tenant, rental_agreement: agreement, invited_email: user.email)

      post accept_tenant_invitation_path(invitation)

      invitation.reload
      expect(invitation).to be_accepted
      expect(invitation.user).to eq(user)
      expect(invitation.landlord_acknowledged_at).to be_nil
      expect(response).to redirect_to(root_path)
    end

    it "matches the email case-insensitively" do
      invitation = create(:agreement_tenant, rental_agreement: agreement, invited_email: user.email.upcase)

      post accept_tenant_invitation_path(invitation)

      expect(invitation.reload).to be_accepted
    end

    it "raises RecordNotFound for an invitation belonging to another user's email" do
      invitation = create(:agreement_tenant, rental_agreement: agreement, invited_email: "someone-else@example.com")

      expect {
        post accept_tenant_invitation_path(invitation)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does not accept an expired invitation and redirects with an alert" do
      invitation = create(:agreement_tenant, :expired, rental_agreement: agreement, invited_email: user.email)

      post accept_tenant_invitation_path(invitation)

      expect(invitation.reload).to be_pending
      expect(invitation.user).to be_nil
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t("tenant_invitations.expired"))
    end
  end

  describe "POST /tenant_invitations/:id/reject" do
    it "rejects a pending invitation matching the signed-in user's email" do
      invitation = create(:agreement_tenant, rental_agreement: agreement, invited_email: user.email)

      post reject_tenant_invitation_path(invitation)

      invitation.reload
      expect(invitation).to be_rejected
      expect(invitation.responded_at).to be_present
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /tenant_invitations/:id/dismiss" do
    it "acknowledges a removed invitation belonging to the signed-in user" do
      invitation = create(:agreement_tenant, :removed, rental_agreement: agreement, user: user, invited_email: user.email)

      post dismiss_tenant_invitation_path(invitation)

      expect(invitation.reload.tenant_acknowledged_at).to be_present
      expect(response).to redirect_to(root_path)
    end
  end

  describe "tenant banner" do
    it "shows an accept/reject banner on the root page for a pending invitation" do
      create(:agreement_tenant, rental_agreement: agreement, invited_email: user.email)

      get root_path

      expect(response.body).to include(I18n.t("tenant_banners.accept"))
    end
  end
end
