class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :auto_login_dev_user if Rails.env.development?
  before_action :authenticate_user!

  private

  def auto_login_dev_user
    return if user_signed_in?
    dev_user = User.find_by(email: "dev@example.com")
    sign_in dev_user if dev_user
  end

  def current_landlord
    @current_landlord ||= current_user&.landlord
  end
  helper_method :current_landlord
end
