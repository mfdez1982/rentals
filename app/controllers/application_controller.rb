class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :set_locale

  private

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
