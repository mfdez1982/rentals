class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :auto_login_dev_user if Rails.env.development?
  before_action :authenticate_user!
  before_action :set_locale

  private

  def auto_login_dev_user
    return if user_signed_in?
    dev_user = User.find_by(email: "dev@example.com")
    sign_in dev_user if dev_user
  end

  def set_locale
    I18n.locale = session[:locale] || I18n.default_locale
  end

  def current_landlord
    @current_landlord ||= current_user&.landlord
  end
  helper_method :current_landlord

  def available_locales
    [:en, :es]
  end
  helper_method :available_locales
end
