class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!

  private

  def current_landlord
    @current_landlord ||= current_user&.landlord
  end
  helper_method :current_landlord
end
