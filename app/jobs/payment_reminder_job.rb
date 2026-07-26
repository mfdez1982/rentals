require "net/smtp"

# Sends the reminder for a single overdue payment: the tenant(s) always, and the
# landlord unless the property opts out. Enqueued once per payment by
# OverduePaymentReminder, so a delivery failure retries just this payment
# without affecting the others.
class PaymentReminderJob < ApplicationJob
  queue_as :default

  # Transient delivery failures retry this payment alone, with backoff. After
  # the attempts are exhausted the job lands in the failed-jobs list, where it
  # can be retried by hand.
  retry_on Net::SMTPError, Net::OpenTimeout, wait: :polynomially_longer, attempts: 5

  def perform(payment)
    # The payment may have been paid between the nightly scan and now — if it's
    # no longer overdue there is nothing to send; the job simply completes.
    return unless payment.overdue?

    agreement = payment.rental_agreement
    property = agreement.property

    agreement.accepted_agreement_tenants.each do |agreement_tenant|
      PaymentReminderMailer.tenant_notice(payment, agreement_tenant).deliver_now
    end

    # The property-level opt-out suppresses only the landlord's copy; tenants
    # are always reminded.
    PaymentReminderMailer.landlord_notice(payment).deliver_now if property.reminders_enabled?

    # Stamp only after a successful send, so a failed-then-retried delivery is
    # not mistaken for "already reminded".
    payment.update_column(:last_reminded_at, Time.current)
  end
end
