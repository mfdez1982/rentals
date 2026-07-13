# Creates or reactivates a pending AgreementTenant invitation for a given
# rental agreement + email, and sends the correct invite email depending on
# whether the email already belongs to a registered User.
#
# Usage:
#   result = TenantInviter.new(rental_agreement: agreement, email: "a@b.com").call
#   result.outcome # => :invited / :already_pending / :already_accepted
#   result.agreement_tenant
class TenantInviter
  Result = Struct.new(:agreement_tenant, :outcome, keyword_init: true)

  def self.call(rental_agreement:, email:)
    new(rental_agreement: rental_agreement, email: email).call
  end

  def initialize(rental_agreement:, email:)
    @rental_agreement = rental_agreement
    @email = email.to_s.downcase.strip
  end

  def call
    existing = rental_agreement.agreement_tenants.for_email(email).order(created_at: :desc).first

    if existing&.accepted?
      return Result.new(agreement_tenant: existing, outcome: :already_accepted)
    end

    if existing&.pending?
      return Result.new(agreement_tenant: existing, outcome: :already_pending)
    end

    agreement_tenant =
      if existing
        reactivate(existing)
      else
        create_new
      end

    deliver_invite(agreement_tenant)

    Result.new(agreement_tenant: agreement_tenant, outcome: :invited)
  end

  private

  attr_reader :rental_agreement, :email

  def reactivate(agreement_tenant)
    agreement_tenant.status = :pending
    agreement_tenant.invited_at = Time.current
    agreement_tenant.responded_at = nil
    agreement_tenant.tenant_acknowledged_at = nil
    # regenerate_invitation_token calls update! internally, which persists
    # every dirty attribute set above in a single write.
    agreement_tenant.regenerate_invitation_token
    agreement_tenant
  end

  def create_new
    rental_agreement.agreement_tenants.create!(invited_email: email)
  end

  def deliver_invite(agreement_tenant)
    if User.find_by(email: email)
      AgreementTenantMailer.notify_existing_user(agreement_tenant).deliver_later
    else
      AgreementTenantMailer.invite_new_user(agreement_tenant).deliver_later
    end
  end
end
