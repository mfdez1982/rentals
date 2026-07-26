# Scans for overdue payments that are due a reminder and emails the tenant(s)
# and (unless the property opts out) the landlord. Only landlords whose plan
# grants the `:payment_reminders` feature are considered.
#
# Reminders repeat on a weekly cadence: each payment is re-notified once its
# last reminder is older than REMINDER_INTERVAL. `last_reminded_at` is stamped
# after sending, so a job that fails partway and retries won't re-notify the
# payments it already handled within the interval.
class OverduePaymentReminder
  REMINDER_INTERVAL = 7.days

  Result = Struct.new(:payments_reminded, :tenant_emails, :landlord_emails, keyword_init: true)

  def self.run(now: Time.current)
    new(now: now).run
  end

  def initialize(now: Time.current)
    @now = now
    @payments_reminded = 0
    @tenant_emails = 0
    @landlord_emails = 0
  end

  def run
    eligible_landlords.each { |landlord| process_landlord(landlord) }

    Result.new(
      payments_reminded: @payments_reminded,
      tenant_emails: @tenant_emails,
      landlord_emails: @landlord_emails
    )
  end

  private

  def eligible_landlords
    Landlord.where(plan: [ :pro, :premium ]).select(&:payment_reminders_allowed?)
  end

  def process_landlord(landlord)
    landlord.properties.each do |property|
      property.rental_agreements.each do |agreement|
        agreement.payments.each do |payment|
          next unless payment.reminder_due?(interval: REMINDER_INTERVAL, now: @now)

          remind(payment, agreement, property)
        end
      end
    end
  end

  def remind(payment, agreement, property)
    agreement.accepted_agreement_tenants.each do |agreement_tenant|
      PaymentReminderMailer.tenant_notice(payment, agreement_tenant).deliver_now
      @tenant_emails += 1
    end

    # The property-level opt-out suppresses only the landlord's copy; tenants
    # are always reminded.
    if property.reminders_enabled?
      PaymentReminderMailer.landlord_notice(payment).deliver_now
      @landlord_emails += 1
    end

    payment.update_column(:last_reminded_at, @now)
    @payments_reminded += 1
  end
end
