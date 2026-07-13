require "rails_helper"

RSpec.describe AvatarHelper, type: :helper do
  describe "#avatar_for_property" do
    let(:property) { build(:property, name: "casa verde") }

    it "returns the upcased first letter as initials" do
      expect(helper.avatar_for_property(property)[:initials]).to eq("C")
    end

    it "returns a color class and hex from the fixed palette, as a matched pair" do
      avatar = helper.avatar_for_property(property)
      entry = AvatarHelper::AVATAR_COLORS.find { |c| c[:class] == avatar[:color_class] }
      expect(entry).to be_present
      expect(entry[:hex]).to eq(avatar[:color_hex])
    end

    it "is deterministic for the same name within a process, case-insensitively" do
      same = helper.avatar_for_property(build(:property, name: "CASA VERDE"))
      expect(helper.avatar_for_property(property)[:color_class]).to eq(same[:color_class])
    end

    # NOTE: cross-process stability is documented in CLAUDE.md but currently
    # broken (String#hash is seeded per process — REFACTOR_REPORT.md P1.1).
    # It cannot be asserted from within a single test process; once fixed with
    # a stable digest, add an example asserting the exact palette entry for a
    # known name.
  end
end
