class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  prepend_before_action :redirect_to_landing_if_needed
  before_action :authenticate_user!
  before_action :set_locale

  private

  def redirect_to_landing_if_needed
    redirect_to landing_path if !user_signed_in? && request.path == "/" && request.method == "GET"
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

  def after_sign_in_path_for(resource)
    resource.admin? ? backoffice_root_path : properties_path
  end
end
