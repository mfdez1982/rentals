class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  prepend_before_action :redirect_to_landing_if_needed
  before_action :authenticate_user!
  before_action :set_locale

  private

  def redirect_to_landing_if_needed
    redirect_to landing_path if request.get? && request.path == "/" && !user_signed_in?
  end

  def set_locale
    I18n.locale = session[:locale] || I18n.default_locale
  end

  def current_landlord
    @current_landlord ||= current_user&.landlord
  end
  helper_method :current_landlord

  def set_property
    @property = current_landlord.properties.find(params[:property_id])
  end

  def available_locales
    [:en, :es]
  end
  helper_method :available_locales

  def after_sign_in_path_for(resource)
    resource.admin? ? backoffice_root_path : properties_path
  end

  # These inline-edit/renew views render only a Turbo Frame fragment, not a full page.
  # Loading them outside a frame (direct navigation, bookmark, refresh) would otherwise
  # render a broken-looking partial page, so bounce back to the full page instead.
  def redirect_unless_turbo_frame_request(fallback_path)
    redirect_to fallback_path unless turbo_frame_request?
  end
end
