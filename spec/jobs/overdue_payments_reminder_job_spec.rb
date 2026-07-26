require "rails_helper"

RSpec.describe OverduePaymentsReminderJob, type: :job do
  it "delegates to the reminder service" do
    expect(OverduePaymentReminder).to receive(:run)
    described_class.perform_now
  end
end
