# Preview all Devise emails at http://localhost:3000/rails/mailers
class DeviseMailerPreview < ActionMailer::Preview
  def reset_password_instructions
    user = sample_user
    DeviseMailer.reset_password_instructions(user, "fake_reset_token_12345")
  end

  def password_change
    user = sample_user
    DeviseMailer.password_change(user)
  end

  def confirmation_instructions
    user = sample_user
    DeviseMailer.confirmation_instructions(user, "fake_confirmation_token")
  end

  private

  def sample_user
    User.first || User.create!(
      email: "landlord@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end
end
