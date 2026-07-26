# Reminder emails for an overdue payment, sent on a weekly cadence by
# OverduePaymentReminder. Tenants always receive theirs; the landlord's copy is
# suppressed when the property has reminders disabled.
class PaymentReminderMailer < ApplicationMailer
  def tenant_notice(payment, agreement_tenant)
    @payment = payment
    @agreement = payment.rental_agreement
    @property = @agreement.property

    mail(
      to: agreement_tenant.invited_email,
      subject: t("payment_reminder_mailer.tenant_notice.subject", property_name: @property.name)
    )
  end

  def landlord_notice(payment)
    @payment = payment
    @agreement = payment.rental_agreement
    @property = @agreement.property

    mail(
      to: @property.landlord.user.email,
      subject: t("payment_reminder_mailer.landlord_notice.subject", property_name: @property.name)
    )
  end
end
