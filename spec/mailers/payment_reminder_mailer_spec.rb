require "rails_helper"

RSpec.describe PaymentReminderMailer, type: :mailer do
  let(:property) { create(:property, name: "Sunny Villa") }
  let(:agreement) { create(:rental_agreement, property: property) }
  let(:payment) { create(:payment, rental_agreement: agreement, due_date: Date.new(2025, 6, 1), amount: 1200) }

  describe "#tenant_notice" do
    let(:agreement_tenant) do
      create(:agreement_tenant, :accepted, rental_agreement: agreement, invited_email: "tenant@example.com")
    end
    let(:mail) { described_class.tenant_notice(payment, agreement_tenant) }

    it "sends to the tenant with an i18n subject mentioning the property" do
      expect(mail.to).to include("tenant@example.com")
      expect(mail.subject).to eq(I18n.t("payment_reminder_mailer.tenant_notice.subject", property_name: "Sunny Villa"))
    end

    it "mentions the property in the body" do
      expect(mail.body.encoded).to include("Sunny Villa")
    end
  end

  describe "#landlord_notice" do
    let(:mail) { described_class.landlord_notice(payment) }

    it "sends to the landlord's user email with an i18n subject" do
      expect(mail.to).to include(property.landlord.user.email)
      expect(mail.subject).to eq(I18n.t("payment_reminder_mailer.landlord_notice.subject", property_name: "Sunny Villa"))
    end
  end
end
