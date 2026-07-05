class LocalesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:set]

  def set
    if params[:locale].in?(I18n.available_locales.map(&:to_s))
      session[:locale] = params[:locale]
    end
    redirect_back fallback_location: root_path
  end
end
