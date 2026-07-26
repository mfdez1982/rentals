require "rails_helper"

RSpec.describe PaymentReminderJob, type: :job do
  before { ActionMailer::Base.deliveries.clear }

  def build_payment(reminders_enabled: true, paid_date: nil, due_date: 20.days.ago.to_date)
    landlord = create(:landlord, plan: :pro)
    property = create(:property, landlord: landlord, reminders_enabled: reminders_enabled)
    agreement = create(:rental_agreement, property: property,
                       start_date: 60.days.ago.to_date, end_date: 60.days.from_now.to_date)
    create(:agreement_tenant, :accepted, rental_agreement: agreement, invited_email: "tenant@example.com")
    create(:payment, rental_agreement: agreement, due_date: due_date, paid_date: paid_date)
  end

  def recipients
    ActionMailer::Base.deliveries.flat_map(&:to)
  end

  it "emails the tenant and the landlord and stamps the payment" do
    payment = build_payment
    landlord_email = payment.rental_agreement.property.landlord.user.email

    described_class.perform_now(payment)

    expect(recipients).to include("tenant@example.com", landlord_email)
    expect(payment.reload.last_reminded_at).to be_present
  end

  it "suppresses the landlord copy when the property opts out, but still reminds the tenant" do
    payment = build_payment(reminders_enabled: false)
    landlord_email = payment.rental_agreement.property.landlord.user.email

    described_class.perform_now(payment)

    expect(recipients).to include("tenant@example.com")
    expect(recipients).not_to include(landlord_email)
    expect(payment.reload.last_reminded_at).to be_present
  end

  it "sends nothing and does not stamp when the payment is already paid" do
    payment = build_payment(paid_date: Date.today)

    described_class.perform_now(payment)

    expect(ActionMailer::Base.deliveries).to be_empty
    expect(payment.reload.last_reminded_at).to be_nil
  end
end
