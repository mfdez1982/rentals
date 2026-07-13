require "rails_helper"

RSpec.describe AgreementTenantMailer, type: :mailer do
  let(:property) { create(:property, name: "Sunny Villa") }
  let(:agreement) { create(:rental_agreement, property: property) }

  describe "#invite_new_user" do
    let(:agreement_tenant) do
      create(:agreement_tenant, rental_agreement: agreement, invited_email: "newtenant@example.com")
    end
    let(:mail) { described_class.invite_new_user(agreement_tenant) }

    it "sends to the invited email with an i18n subject" do
      expect(mail.to).to include("newtenant@example.com")
      expect(mail.subject).to eq(I18n.t("agreement_tenant_mailer.invite_new_user.subject", property_name: "Sunny Villa"))
    end

    it "includes a registration link with the invitation token" do
      expect(mail.body.encoded).to include("invitation_token=#{agreement_tenant.invitation_token}")
      expect(mail.body.encoded).to include("Sunny Villa")
    end
  end

  describe "#notify_existing_user" do
    let(:agreement_tenant) do
      create(:agreement_tenant, rental_agreement: agreement, invited_email: "existing@example.com")
    end
    let(:mail) { described_class.notify_existing_user(agreement_tenant) }

    it "sends to the invited email with an i18n subject" do
      expect(mail.to).to include("existing@example.com")
      expect(mail.subject).to eq(I18n.t("agreement_tenant_mailer.notify_existing_user.subject", property_name: "Sunny Villa"))
    end

    it "links to the root url and mentions the property" do
      expect(mail.body.encoded).to include(root_url)
      expect(mail.body.encoded).to include("Sunny Villa")
    end
  end

  describe "#removed" do
    let(:agreement_tenant) do
      create(:agreement_tenant, :removed, rental_agreement: agreement, invited_email: "removed@example.com")
    end
    let(:mail) { described_class.removed(agreement_tenant) }

    it "sends to the invited email with an i18n subject" do
      expect(mail.to).to include("removed@example.com")
      expect(mail.subject).to eq(I18n.t("agreement_tenant_mailer.removed.subject", property_name: "Sunny Villa"))
    end

    it "mentions the property in the body" do
      expect(mail.body.encoded).to include("Sunny Villa")
    end
  end
end
