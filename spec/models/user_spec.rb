require "rails_helper"

RSpec.describe User, type: :model do
  describe "landlord auto-creation on sign-up" do
    it "creates a landlord profile for landlord-role users" do
      user = create(:user, email: "maria.garcia@example.com")
      expect(user.landlord).to be_present
      expect(user.landlord.name).to eq("maria.garcia")
    end

    it "does not create a landlord for admin users" do
      admin = create(:user, :admin)
      expect(admin.landlord).to be_nil
    end
  end

  describe "roles" do
    it "defaults to landlord" do
      expect(User.new.role).to eq("landlord")
    end
  end

  describe "dependent destroy" do
    it "removes the landlord profile with the user" do
      user = create(:user)
      expect { user.destroy }.to change(Landlord, :count).by(-1)
    end
  end
end
