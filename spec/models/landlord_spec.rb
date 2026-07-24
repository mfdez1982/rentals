require "rails_helper"

RSpec.describe Landlord, type: :model do
  describe "plan" do
    it "defaults to free" do
      expect(create(:landlord).plan).to eq("free")
    end

    it "exposes the tier enum values" do
      expect(Landlord.plans.keys).to eq(%w[free pro premium])
    end
  end

  describe "#flipper_id" do
    it "identifies the landlord as a Flipper actor" do
      landlord = create(:landlord)
      expect(landlord.flipper_id).to eq("Landlord;#{landlord.id}")
    end
  end

  describe "plan-based Flipper groups" do
    let(:free) { create(:landlord, plan: :free) }
    let(:pro) { create(:landlord, plan: :pro) }
    let(:premium) { create(:landlord, plan: :premium) }

    before do
      Flipper.enable_group(:sample_feature, :pro_and_up)
      Flipper.enable_group(:sample_premium_feature, :premium_only)
    end

    after do
      Flipper.remove(:sample_feature)
      Flipper.remove(:sample_premium_feature)
    end

    it "grants pro_and_up features to pro and premium, not free" do
      expect(Flipper.enabled?(:sample_feature, free)).to be(false)
      expect(Flipper.enabled?(:sample_feature, pro)).to be(true)
      expect(Flipper.enabled?(:sample_feature, premium)).to be(true)
    end

    it "grants premium_only features to premium alone" do
      expect(Flipper.enabled?(:sample_premium_feature, free)).to be(false)
      expect(Flipper.enabled?(:sample_premium_feature, pro)).to be(false)
      expect(Flipper.enabled?(:sample_premium_feature, premium)).to be(true)
    end
  end

  describe "#multi_property? and #property_limit_reached?" do
    before { Flipper.enable_group(:multi_property, :pro_and_up) }
    after { Flipper.remove(:multi_property) }

    it "is granted to pro and premium, not free" do
      expect(create(:landlord, plan: :free).multi_property?).to be(false)
      expect(create(:landlord, plan: :pro).multi_property?).to be(true)
      expect(create(:landlord, plan: :premium).multi_property?).to be(true)
    end

    it "is true for a free landlord with a property, false otherwise" do
      free = create(:landlord, plan: :free)
      expect(free.property_limit_reached?).to be(false)

      create(:property, landlord: free)
      expect(free.property_limit_reached?).to be(true)
    end

    it "is never true for pro or premium landlords" do
      pro = create(:landlord, plan: :pro)
      create(:property, landlord: pro)
      expect(pro.property_limit_reached?).to be(false)
    end
  end
end
