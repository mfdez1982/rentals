# Dispatcher for overdue-payment reminders. Scans for overdue payments that are
# due a reminder and enqueues one PaymentReminderJob per payment — it does not
# send anything itself. The per-payment jobs (drained by Solid Queue workers)
# do the sending, so a delivery failure retries just that one payment.
#
# Only landlords whose plan grants the `:payment_reminders` feature are
# considered. Reminders repeat weekly: a payment becomes due again once its
# `last_reminded_at` (stamped by the per-payment job after a successful send) is
# older than REMINDER_INTERVAL.
class OverduePaymentReminder
  REMINDER_INTERVAL = 7.days

  def self.run(now: Time.current)
    new(now: now).run
  end

  def initialize(now: Time.current)
    @now = now
  end

  def run
    eligible_landlords.each { |landlord| dispatch_landlord(landlord) }
  end

  private

  def eligible_landlords
    Landlord.where(plan: [ :pro, :premium ]).select(&:payment_reminders_allowed?)
  end

  def dispatch_landlord(landlord)
    landlord.properties.each do |property|
      property.rental_agreements.each do |agreement|
        agreement.payments.each do |payment|
          next unless payment.reminder_due?(interval: REMINDER_INTERVAL, now: @now)

          PaymentReminderJob.perform_later(payment)
        end
      end
    end
  end
end
