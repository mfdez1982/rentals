class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  prepend_before_action :redirect_to_landing_if_needed
  before_action :authenticate_user!
  before_action :set_locale
  before_action :redirect_root_appropriately

  private

  def redirect_to_landing_if_needed
    redirect_to landing_path if request.get? && request.path == "/" && !user_signed_in?
  end

  # A user can be a landlord and/or a tenant. When they hit the root path, send
  # them to the dashboard that fits: admins to the backoffice, tenant-only users
  # (no properties of their own) to their rentals, and everyone else to the
  # landlord property dashboard (rendered at root, so no redirect needed there).
  def redirect_root_appropriately
    return unless request.get? && request.path == "/" && user_signed_in?

    if current_user.admin?
      redirect_to backoffice_root_path
    elsif current_landlord&.properties&.none? && current_user.tenant?
      redirect_to my_rentals_path
    end
  end

  def home_path_for(user)
    return backoffice_root_path if user.admin?
    return properties_path if user.landlord&.properties&.exists?
    return my_rentals_path if user.tenant?

    properties_path
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

  def pending_tenant_invitations
    @pending_tenant_invitations ||= if current_user
      AgreementTenant.pending
                     .where("lower(invited_email) = ?", current_user.email.downcase)
                     .where("invited_at > ?", AgreementTenant::INVITE_TTL.ago)
                     .includes(rental_agreement: :property)
    else
      AgreementTenant.none
    end
  end
  helper_method :pending_tenant_invitations

  def tenant_removal_notices
    @tenant_removal_notices ||= if current_user
      current_user.agreement_tenants.removed.where(tenant_acknowledged_at: nil).includes(rental_agreement: :property)
    else
      AgreementTenant.none
    end
  end
  helper_method :tenant_removal_notices

  def landlord_tenant_notifications
    @landlord_tenant_notifications ||= if current_landlord
      AgreementTenant.where(status: [:accepted, :rejected], landlord_acknowledged_at: nil)
                     .joins(rental_agreement: { property: :landlord })
                     .where(landlords: { id: current_landlord.id })
                     .includes(rental_agreement: :property)
    else
      AgreementTenant.none
    end
  end
  helper_method :landlord_tenant_notifications

  def available_locales
    [:en, :es]
  end
  helper_method :available_locales

  def after_sign_in_path_for(resource)
    home_path_for(resource)
  end

  # These inline-edit/renew views render only a Turbo Frame fragment, not a full page.
  # Loading them outside a frame (direct navigation, bookmark, refresh) would otherwise
  # render a broken-looking partial page, so bounce back to the full page instead.
  def redirect_unless_turbo_frame_request(fallback_path)
    redirect_to fallback_path unless turbo_frame_request?
  end
end
