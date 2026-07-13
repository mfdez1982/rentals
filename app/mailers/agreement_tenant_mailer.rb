# Emails sent to a prospective/removed tenant on the landlord side of the
# tenant-invitation flow (Phase 2). Acceptance/rejection emails are not part
# of this phase.
class AgreementTenantMailer < ApplicationMailer
  def invite_new_user(agreement_tenant)
    @agreement_tenant = agreement_tenant
    @agreement = agreement_tenant.rental_agreement
    @property = @agreement.property
    @registration_url = new_user_registration_url(invitation_token: agreement_tenant.invitation_token)

    mail(
      to: agreement_tenant.invited_email,
      subject: t("agreement_tenant_mailer.invite_new_user.subject", property_name: @property.name)
    )
  end

  def notify_existing_user(agreement_tenant)
    @agreement_tenant = agreement_tenant
    @agreement = agreement_tenant.rental_agreement
    @property = @agreement.property
    @root_url = root_url

    mail(
      to: agreement_tenant.invited_email,
      subject: t("agreement_tenant_mailer.notify_existing_user.subject", property_name: @property.name)
    )
  end

  def removed(agreement_tenant)
    @agreement_tenant = agreement_tenant
    @agreement = agreement_tenant.rental_agreement
    @property = @agreement.property

    mail(
      to: agreement_tenant.invited_email,
      subject: t("agreement_tenant_mailer.removed.subject", property_name: @property.name)
    )
  end
end
