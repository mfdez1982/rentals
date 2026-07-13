require "rails_helper"

RSpec.describe "AgreementTenants", type: :request do
  let(:user) { create(:user) }
  let(:landlord) { user.landlord }
  let(:property) { create(:property, landlord: landlord) }
  let(:agreement) { create(:rental_agreement, property: property) }

  before { sign_in user }

  describe "GET /properties/:property_id/rental_agreements/:id (tenants section)" do
    it "still renders the agreement page with the tenants section" do
      get property_rental_agreement_path(property, agreement)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("agreement_tenants.tab_label"))
    end
  end

  describe "POST /properties/:property_id/rental_agreements/:id/agreement_tenants" do
    it "invites a brand new email and enqueues invite_new_user" do
      expect {
        post property_rental_agreement_agreement_tenants_path(property, agreement),
             params: { agreement_tenant: { invited_email: "newtenant@example.com" } }
      }.to change(agreement.agreement_tenants, :count).by(1)

      expect(response).to redirect_to(property_rental_agreement_path(property, agreement))
      expect(agreement.agreement_tenants.last.invited_email).to eq("newtenant@example.com")
      expect(agreement.agreement_tenants.last).to be_pending
    end

    it "enqueues invite_new_user for an email with no matching user" do
      expect {
        post property_rental_agreement_agreement_tenants_path(property, agreement),
             params: { agreement_tenant: { invited_email: "newtenant@example.com" } }
      }.to have_enqueued_mail(AgreementTenantMailer, :invite_new_user)
    end

    it "enqueues notify_existing_user when the email matches an existing user" do
      existing = create(:user, email: "existing@example.com")

      expect {
        post property_rental_agreement_agreement_tenants_path(property, agreement),
             params: { agreement_tenant: { invited_email: existing.email } }
      }.to have_enqueued_mail(AgreementTenantMailer, :notify_existing_user)
    end

    it "errors on a blank email without creating a record" do
      expect {
        post property_rental_agreement_agreement_tenants_path(property, agreement),
             params: { agreement_tenant: { invited_email: "" } }
      }.not_to change(agreement.agreement_tenants, :count)

      expect(response).to redirect_to(property_rental_agreement_path(property, agreement))
    end

    it "does not create a second row for an already-pending invite" do
      create(:agreement_tenant, rental_agreement: agreement, invited_email: "dup@example.com", status: :pending)

      expect {
        post property_rental_agreement_agreement_tenants_path(property, agreement),
             params: { agreement_tenant: { invited_email: "dup@example.com" } }
      }.not_to change(agreement.agreement_tenants, :count)
    end

    it "cannot invite a tenant on another landlord's agreement" do
      other_agreement = create(:rental_agreement)
      expect {
        post property_rental_agreement_agreement_tenants_path(other_agreement.property, other_agreement),
             params: { agreement_tenant: { invited_email: "someone@example.com" } }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE /properties/:property_id/rental_agreements/:id/agreement_tenants/:id" do
    it "soft-removes an accepted tenant (does not delete the row) and enqueues removed mail" do
      tenant = create(:agreement_tenant, :accepted, rental_agreement: agreement)

      expect {
        expect {
          delete property_rental_agreement_agreement_tenant_path(property, agreement, tenant)
        }.to have_enqueued_mail(AgreementTenantMailer, :removed)
      }.not_to change(AgreementTenant, :count)

      expect(tenant.reload).to be_removed
      expect(response).to redirect_to(property_rental_agreement_path(property, agreement))
    end

    it "hard-deletes a pending invite" do
      tenant = create(:agreement_tenant, rental_agreement: agreement, status: :pending)

      expect {
        delete property_rental_agreement_agreement_tenant_path(property, agreement, tenant)
      }.to change(AgreementTenant, :count).by(-1)

      expect(response).to redirect_to(property_rental_agreement_path(property, agreement))
    end

    it "cannot destroy another landlord's agreement tenant" do
      other_agreement = create(:rental_agreement)
      other_tenant = create(:agreement_tenant, rental_agreement: other_agreement)

      expect {
        delete property_rental_agreement_agreement_tenant_path(other_agreement.property, other_agreement, other_tenant)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST /properties/:property_id/rental_agreements/:id/agreement_tenants/:id/retry" do
    it "moves a rejected invite back to pending and resends the invite" do
      tenant = create(:agreement_tenant, :rejected, rental_agreement: agreement, invited_email: "retryme@example.com")

      expect {
        post retry_property_rental_agreement_agreement_tenant_path(property, agreement, tenant)
      }.to have_enqueued_mail(AgreementTenantMailer, :invite_new_user)

      expect(tenant.reload).to be_pending
      expect(response).to redirect_to(property_rental_agreement_path(property, agreement))
    end
  end

  describe "POST /properties/:property_id/rental_agreements/:id/agreement_tenants/:id/acknowledge" do
    it "dismisses the landlord notification for an accepted tenant" do
      tenant = create(:agreement_tenant, :accepted, rental_agreement: agreement)

      post acknowledge_property_rental_agreement_agreement_tenant_path(property, agreement, tenant)

      expect(tenant.reload.landlord_acknowledged_at).to be_present
      expect(response).to redirect_to(property_rental_agreement_path(property, agreement))
    end
  end
end
