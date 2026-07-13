require "rails_helper"

RSpec.describe AvatarHelper, type: :helper do
  describe "#avatar_for_property" do
    let(:property) { build(:property, name: "casa verde") }

    it "returns the upcased first letter as initials" do
      expect(helper.avatar_for_property(property)[:initials]).to eq("C")
    end

    it "returns a color class from the fixed palette" do
      avatar = helper.avatar_for_property(property)
      expect(AvatarHelper::AVATAR_COLORS).to include(avatar[:color_class])
    end

    it "is deterministic for the same name within a process, case-insensitively" do
      same = helper.avatar_for_property(build(:property, name: "CASA VERDE"))
      expect(helper.avatar_for_property(property)[:color_class]).to eq(same[:color_class])
    end

    it "is deterministic across processes (stable digest, not String#hash)" do
      # String#hash is randomly seeded per process, so this can only be verified
      # by recomputing the same stable-digest formula the helper uses (MD5,
      # not String#hash) and checking it matches — a real cross-process
      # assertion would require a separate Ruby invocation.
      expected_index = Digest::MD5.hexdigest("casa verde").to_i(16) % AvatarHelper::AVATAR_COLORS.length
      expect(helper.avatar_for_property(property)[:color_class]).to eq(AvatarHelper::AVATAR_COLORS[expected_index])
    end
  end
end
