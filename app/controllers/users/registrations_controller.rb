module Users
  # Extends Devise registration to claim a pending tenant invitation when a user
  # signs up via a tokened invite link. The invitation token is the proof of
  # email ownership (this app has no :confirmable), so a valid, unexpired,
  # still-pending token is what authorizes claiming the invitation — not a plain
  # email match. An expired or already-used token is silently ignored and the
  # person simply registers as a normal user.
  class RegistrationsController < Devise::RegistrationsController
    def new
      @invitation_token = params[:invitation_token]
      super do |resource|
        invitation = claimable_invitation
        resource.email = invitation.invited_email if invitation
      end
    end

    def create
      @invitation_token = params.dig(:user, :invitation_token).presence || params[:invitation_token].presence
      super do |resource|
        claim_invitation_for(resource) if resource.persisted?
      end
    end

    private

    def claimable_invitation
      return if @invitation_token.blank?

      invitation = AgreementTenant.find_by(invitation_token: @invitation_token)
      invitation if invitation&.claimable?
    end

    def claim_invitation_for(user)
      invitation = claimable_invitation
      return unless invitation

      invitation.update!(
        status: :accepted,
        user: user,
        responded_at: Time.current,
        landlord_acknowledged_at: nil
      )
    end
  end
end
