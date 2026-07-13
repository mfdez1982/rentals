class TenantInvitationsController < ApplicationController
  before_action :set_pending_invitation, only: [:accept, :reject]

  def accept
    if @invitation.claimable?
      @invitation.update!(
        status: :accepted,
        user: current_user,
        responded_at: Time.current,
        landlord_acknowledged_at: nil
      )
      redirect_back fallback_location: root_path, notice: t("tenant_invitations.accepted")
    else
      redirect_back fallback_location: root_path, alert: t("tenant_invitations.expired")
    end
  end

  def reject
    @invitation.update!(status: :rejected, responded_at: Time.current, landlord_acknowledged_at: nil)
    redirect_back fallback_location: root_path, notice: t("tenant_invitations.rejected")
  end

  def dismiss
    invitation = current_user.agreement_tenants.removed.find(params[:id])
    invitation.update!(tenant_acknowledged_at: Time.current)
    redirect_back fallback_location: root_path, notice: t("tenant_invitations.dismissed")
  end

  private

  def set_pending_invitation
    @invitation = AgreementTenant.pending
                                  .where("lower(invited_email) = ?", current_user.email.downcase)
                                  .find(params[:id])
  end
end
