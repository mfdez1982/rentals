# Nightly entry point (see config/recurring.yml) that scans for overdue
# payments due a reminder and emails tenants and landlords.
class OverduePaymentsReminderJob < ApplicationJob
  queue_as :default

  def perform
    OverduePaymentReminder.run
  end
end
