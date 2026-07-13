require "rails_helper"

RSpec.describe "Devise Mailer", type: :mailer do
  describe "password reset email" do
    it "sends a reset password instructions email" do
      user = create(:user, email: "landlord@example.com")
      user.send_reset_password_instructions

      expect(ActionMailer::Base.deliveries.count).to eq(1)
      email = ActionMailer::Base.deliveries.last

      expect(email.to).to include("landlord@example.com")
      expect(email.from).to include("noreply@example.com")
      expect(email.subject).to include("password")
    end

    it "includes the reset password URL in the email" do
      user = create(:user, email: "landlord@example.com")
      user.send_reset_password_instructions

      email = ActionMailer::Base.deliveries.last
      expect(email.body.encoded).to include("/users/password/edit")
    end
  end

  describe "password change confirmation email" do
    it "sends a password change email after update" do
      user = create(:user)
      user.update(password: "newpassword123", password_confirmation: "newpassword123")

      email = ActionMailer::Base.deliveries.last
      expect(email.to).to include(user.email)
      expect(email.subject).to match(/password/i)
    end
  end
end
