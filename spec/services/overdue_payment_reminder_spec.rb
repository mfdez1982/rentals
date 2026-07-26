require "rails_helper"

RSpec.describe OverduePaymentReminder do
  before do
    Flipper.enable_group(:payment_reminders, :pro_and_up)
    ActionMailer::Base.deliveries.clear
  end

  after { Flipper.remove(:payment_reminders) }

  # Builds a full landlord → property → agreement → overdue payment tree with
  # one accepted tenant.
  def build_overdue(plan: :pro, reminders_enabled: true, last_reminded_at: nil, due_date: 20.days.ago.to_date)
    landlord = create(:landlord, plan: plan)
    property = create(:property, landlord: landlord, reminders_enabled: reminders_enabled)
    agreement = create(:rental_agreement, property: property,
                       start_date: 60.days.ago.to_date, end_date: 60.days.from_now.to_date)
    create(:agreement_tenant, :accepted, rental_agreement: agreement, invited_email: "tenant@example.com")
    payment = create(:payment, rental_agreement: agreement, due_date: due_date, last_reminded_at: last_reminded_at)
    { landlord: landlord, property: property, agreement: agreement, payment: payment }
  end

  def recipients
    ActionMailer::Base.deliveries.flat_map(&:to)
  end

  it "emails the tenant and the landlord and stamps the payment" do
    tree = build_overdue
    result = described_class.run

    expect(recipients).to include("tenant@example.com", tree[:landlord].user.email)
    expect(result.payments_reminded).to eq(1)
    expect(tree[:payment].reload.last_reminded_at).to be_present
  end

  it "does nothing for a landlord without the feature (free plan)" do
    tree = build_overdue(plan: :free)
    result = described_class.run

    expect(ActionMailer::Base.deliveries).to be_empty
    expect(result.payments_reminded).to eq(0)
    expect(tree[:payment].reload.last_reminded_at).to be_nil
  end

  it "suppresses the landlord copy when the property opts out, but still reminds the tenant" do
    tree = build_overdue(reminders_enabled: false)
    described_class.run

    expect(recipients).to include("tenant@example.com")
    expect(recipients).not_to include(tree[:landlord].user.email)
    expect(tree[:payment].reload.last_reminded_at).to be_present
  end

  it "skips a payment reminded within the cadence interval" do
    build_overdue(last_reminded_at: 2.days.ago)
    result = described_class.run

    expect(ActionMailer::Base.deliveries).to be_empty
    expect(result.payments_reminded).to eq(0)
  end

  it "re-reminds once the last reminder is older than the interval" do
    build_overdue(last_reminded_at: 8.days.ago)
    result = described_class.run

    expect(result.payments_reminded).to eq(1)
    expect(recipients).to include("tenant@example.com")
  end

  it "does not remind a payment that is not overdue" do
    build_overdue(due_date: 5.days.from_now.to_date)
    result = described_class.run

    expect(ActionMailer::Base.deliveries).to be_empty
    expect(result.payments_reminded).to eq(0)
  end
end
