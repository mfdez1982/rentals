require "rails_helper"

RSpec.describe OverduePaymentReminder do
  before { Flipper.enable_group(:payment_reminders, :pro_and_up) }
  after { Flipper.remove(:payment_reminders) }

  # Builds a full landlord → property → agreement → overdue payment tree with
  # one accepted tenant, and returns the payment.
  def build_overdue(plan: :pro, last_reminded_at: nil, due_date: 20.days.ago.to_date)
    landlord = create(:landlord, plan: plan)
    property = create(:property, landlord: landlord)
    agreement = create(:rental_agreement, property: property,
                       start_date: 60.days.ago.to_date, end_date: 60.days.from_now.to_date)
    create(:agreement_tenant, :accepted, rental_agreement: agreement)
    create(:payment, rental_agreement: agreement, due_date: due_date, last_reminded_at: last_reminded_at)
  end

  it "enqueues one PaymentReminderJob per due payment" do
    payment = build_overdue

    expect { described_class.run }
      .to have_enqueued_job(PaymentReminderJob).with(payment).exactly(:once)
  end

  it "enqueues nothing for a landlord without the feature (free plan)" do
    build_overdue(plan: :free)

    expect { described_class.run }.not_to have_enqueued_job(PaymentReminderJob)
  end

  it "does not enqueue a payment reminded within the cadence interval" do
    build_overdue(last_reminded_at: 2.days.ago)

    expect { described_class.run }.not_to have_enqueued_job(PaymentReminderJob)
  end

  it "enqueues again once the last reminder is older than the interval" do
    payment = build_overdue(last_reminded_at: 8.days.ago)

    expect { described_class.run }.to have_enqueued_job(PaymentReminderJob).with(payment)
  end

  it "does not enqueue a payment that is not overdue" do
    build_overdue(due_date: 5.days.from_now.to_date)

    expect { described_class.run }.not_to have_enqueued_job(PaymentReminderJob)
  end
end
