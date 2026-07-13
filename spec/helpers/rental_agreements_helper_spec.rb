require "rails_helper"

RSpec.describe RentalAgreementsHelper, type: :helper do
  let(:property) { create(:property) }
  let(:active)   { create(:rental_agreement, property: property, start_date: 1.month.ago.to_date, end_date: 1.month.from_now.to_date) }
  let(:upcoming) { create(:rental_agreement, property: property, start_date: 2.months.from_now.to_date, end_date: 4.months.from_now.to_date) }
  let(:expired)  { create(:rental_agreement, property: property, start_date: 1.year.ago.to_date, end_date: 2.months.ago.to_date) }

  describe "#agreement_status" do
    it "returns a translated status label" do
      expect(helper.agreement_status(active)).to eq(I18n.t("rental_agreements.status_active"))
      expect(helper.agreement_status(upcoming)).to eq(I18n.t("rental_agreements.status_upcoming"))
      expect(helper.agreement_status(expired)).to eq(I18n.t("rental_agreements.status_expired"))
    end
  end

  describe "#agreement_status_badge_class" do
    it "returns the matching badge class" do
      expect(helper.agreement_status_badge_class(active)).to eq("badge-success")
      expect(helper.agreement_status_badge_class(upcoming)).to eq("badge-info")
      expect(helper.agreement_status_badge_class(expired)).to eq("badge-ghost")
    end
  end
end
