require "rails_helper"

RSpec.describe AgreementTenant, type: :model do
  let(:property) { create(:property) }
  let(:rental_agreement) { create(:rental_agreement, property: property) }

  describe "associations" do
    it "belongs to rental_agreement" do
      agreement_tenant = build(:agreement_tenant, rental_agreement: rental_agreement)
      expect(agreement_tenant.rental_agreement).to eq(rental_agreement)
    end

    it "has an optional user association" do
      agreement_tenant = build(:agreement_tenant, rental_agreement: rental_agreement, user: nil)
      expect(agreement_tenant).to be_valid
      expect(agreement_tenant.user).to be_nil
    end
  end

  describe "validations" do
    it "requires invited_email" do
      agreement_tenant = build(:agreement_tenant, rental_agreement: rental_agreement, invited_email: nil)
      expect(agreement_tenant).not_to be_valid
    end

    it "requires a rental_agreement" do
      agreement_tenant = build(:agreement_tenant, rental_agreement: nil)
      expect(agreement_tenant).not_to be_valid
    end

    it "is valid with all required attributes" do
      agreement_tenant = build(:agreement_tenant, rental_agreement: rental_agreement)
      expect(agreement_tenant).to be_valid
    end

    it "sets invited_at automatically when blank" do
      agreement_tenant = build(:agreement_tenant, rental_agreement: rental_agreement, invited_at: nil)
      agreement_tenant.valid?
      expect(agreement_tenant.invited_at).to be_present
    end
  end

  describe "email normalization" do
    it "downcases and strips invited_email before validation" do
      agreement_tenant = build(:agreement_tenant, rental_agreement: rental_agreement,
                                invited_email: "  Tenant@Example.COM  ")
      agreement_tenant.valid?
      expect(agreement_tenant.invited_email).to eq("tenant@example.com")
    end

    it "does not blow up when invited_email is nil" do
      agreement_tenant = build(:agreement_tenant, rental_agreement: rental_agreement, invited_email: nil)
      expect { agreement_tenant.valid? }.not_to raise_error
    end
  end

  describe "invitation_token" do
    it "is generated automatically on save" do
      agreement_tenant = create(:agreement_tenant, rental_agreement: rental_agreement)
      expect(agreement_tenant.invitation_token).to be_present
    end

    it "is unique" do
      first = create(:agreement_tenant, rental_agreement: rental_agreement)
      second = create(:agreement_tenant, rental_agreement: rental_agreement)
      expect(first.invitation_token).not_to eq(second.invitation_token)
    end
  end

  describe "enums" do
    it "has pending, accepted, rejected and removed statuses" do
      expect(AgreementTenant.statuses).to eq(
        "pending" => 0, "accepted" => 1, "rejected" => 2, "removed" => 3
      )
    end

    it "defaults to pending" do
      expect(AgreementTenant.new.status).to eq("pending")
    end
  end

  describe "#expired?" do
    it "is true when pending and invited more than INVITE_TTL ago" do
      agreement_tenant = build(:agreement_tenant, :expired, rental_agreement: rental_agreement)
      expect(agreement_tenant).to be_expired
    end

    it "is false when pending and invited recently" do
      agreement_tenant = build(:agreement_tenant, rental_agreement: rental_agreement, invited_at: Time.current)
      expect(agreement_tenant).not_to be_expired
    end

    it "is false when not pending, even if invited long ago" do
      agreement_tenant = build(:agreement_tenant, :accepted, rental_agreement: rental_agreement,
                                invited_at: (AgreementTenant::INVITE_TTL + 1.day).ago)
      expect(agreement_tenant).not_to be_expired
    end
  end

  describe "#claimable?" do
    it "is true when pending and not expired" do
      agreement_tenant = build(:agreement_tenant, rental_agreement: rental_agreement)
      expect(agreement_tenant.claimable?).to be true
    end

    it "is false when expired" do
      agreement_tenant = build(:agreement_tenant, :expired, rental_agreement: rental_agreement)
      expect(agreement_tenant.claimable?).to be false
    end

    it "is false when not pending" do
      agreement_tenant = build(:agreement_tenant, :accepted, rental_agreement: rental_agreement)
      expect(agreement_tenant.claimable?).to be false
    end
  end

  describe ".for_email" do
    it "matches case-insensitively" do
      agreement_tenant = create(:agreement_tenant, rental_agreement: rental_agreement,
                                 invited_email: "tenant@example.com")
      expect(AgreementTenant.for_email("Tenant@EXAMPLE.com")).to contain_exactly(agreement_tenant)
    end
  end

  describe ".live" do
    it "includes pending and accepted, excludes rejected and removed" do
      pending = create(:agreement_tenant, rental_agreement: rental_agreement)
      accepted = create(:agreement_tenant, :accepted, rental_agreement: rental_agreement)
      create(:agreement_tenant, :rejected, rental_agreement: rental_agreement)
      create(:agreement_tenant, :removed, rental_agreement: rental_agreement)

      expect(AgreementTenant.live).to contain_exactly(pending, accepted)
    end
  end

  describe "dependent destroy" do
    it "is destroyed when its rental_agreement is destroyed" do
      agreement_tenant = create(:agreement_tenant, rental_agreement: rental_agreement)
      expect { rental_agreement.destroy }.to change(AgreementTenant, :count).by(-1)
      expect { agreement_tenant.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "is destroyed when its user is destroyed" do
      agreement_tenant = create(:agreement_tenant, :accepted, rental_agreement: rental_agreement)
      user = agreement_tenant.user
      expect { user.destroy }.to change(AgreementTenant, :count).by(-1)
      expect { agreement_tenant.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
