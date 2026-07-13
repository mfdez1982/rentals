require "rails_helper"

RSpec.describe "Payments", type: :request do
  let(:user) { create(:user) }
  let(:landlord) { user.landlord }
  let(:property) { create(:property, landlord: landlord) }
  let(:agreement) do
    create(:rental_agreement, property: property,
           start_date: 6.months.ago.to_date, end_date: 6.months.from_now.to_date)
  end
  let(:agreement_path) { property_rental_agreement_path(property, agreement) }

  before { sign_in user }

  describe "POST /properties/:pid/rental_agreements/:aid/payments/create_recurring" do
    let(:recurring_path) { create_recurring_property_rental_agreement_payments_path(property, agreement) }

    it "creates one payment per month starting at the given date" do
      post recurring_path, params: { start_date: "2026-08-01", count: "3", amount: "700.00" }
      expect(response).to redirect_to(agreement_path)
      expect(agreement.payments.order(:due_date).pluck(:due_date)).to eq([
        Date.new(2026, 8, 1), Date.new(2026, 9, 1), Date.new(2026, 10, 1)
      ])
      expect(agreement.payments.pluck(:amount).uniq).to eq([700.00])
    end

    it "clamps the count to a maximum of 12" do
      post recurring_path, params: { start_date: "2026-08-01", count: "50", amount: "700.00" }
      expect(agreement.payments.count).to eq(12)
    end

    it "clamps the count to a minimum of 1" do
      post recurring_path, params: { start_date: "2026-08-01", count: "0", amount: "700.00" }
      expect(agreement.payments.count).to eq(1)
    end

    it "preserves the end-of-month day sequence Ruby's month-shift produces" do
      post recurring_path, params: { start_date: "2026-01-31", count: "3", amount: "700.00" }
      # Date#>> clamps to the last day of shorter months
      expect(agreement.payments.order(:due_date).pluck(:due_date)).to eq([
        Date.new(2026, 1, 31), Date.new(2026, 2, 28), Date.new(2026, 3, 31)
      ])
    end

    it "redirects with an alert when the amount is invalid" do
      post recurring_path, params: { start_date: "2026-08-01", count: "3", amount: "" }
      expect(response).to redirect_to(agreement_path)
      expect(flash[:alert]).to be_present
      expect(agreement.payments.count).to eq(0)
    end

    # FIXED (see REFACTOR_REPORT.md P1.2): a blank/invalid start date used to raise
    # ArgumentError (500 in production). It is now rescued and redirects back with
    # a translated alert, creating no payments.
    it "redirects with an alert instead of raising on a blank start date" do
      expect {
        post recurring_path, params: { start_date: "", count: "3", amount: "700.00" }
      }.not_to raise_error
      expect(response).to redirect_to(agreement_path)
      expect(flash[:alert]).to be_present
      expect(agreement.payments.count).to eq(0)
    end

    it "redirects with an alert instead of raising on a garbage start date" do
      expect {
        post recurring_path, params: { start_date: "not-a-date", count: "3", amount: "700.00" }
      }.not_to raise_error
      expect(response).to redirect_to(agreement_path)
      expect(flash[:alert]).to be_present
      expect(agreement.payments.count).to eq(0)
    end

    # FIXED (see REFACTOR_REPORT.md P1.2): the creation loop is now wrapped in a
    # transaction, so a mid-loop validation failure leaves no partial data behind.
    # `Payment#valid?` is stubbed to fail on the 2nd of 3 iterations so the 1st
    # would otherwise already be committed without the transaction fix.
    it "leaves no partial data when a later payment in the batch fails validation" do
      attempt = 0
      allow_any_instance_of(Payment).to receive(:valid?).and_wrap_original do |original, *args|
        attempt += 1
        attempt == 2 ? false : original.call(*args)
      end

      post recurring_path, params: { start_date: "2026-08-01", count: "3", amount: "700.00" }

      expect(response).to redirect_to(agreement_path)
      expect(flash[:alert]).to be_present
      expect(agreement.payments.count).to eq(0)
    end

    it "cannot create payments on another landlord's agreement" do
      other = create(:rental_agreement)
      expect {
        post create_recurring_property_rental_agreement_payments_path(other.property, other),
             params: { start_date: "2026-08-01", count: "1", amount: "700.00" }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET /properties/:pid/rental_agreements/:aid/payments/:id/edit" do
    let(:payment) { create(:payment, rental_agreement: agreement) }

    it "redirects to the agreement when not a turbo frame request" do
      get edit_property_rental_agreement_payment_path(property, agreement, payment)
      expect(response).to redirect_to(agreement_path)
    end

    it "renders inside a turbo frame request" do
      get edit_property_rental_agreement_payment_path(property, agreement, payment),
          headers: { "Turbo-Frame" => "payment_edit_frame" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /properties/:pid/rental_agreements/:aid/payments/:id" do
    let(:payment) { create(:payment, rental_agreement: agreement) }

    it "updates the payment and redirects to the agreement" do
      patch property_rental_agreement_payment_path(property, agreement, payment), params: {
        payment: { paid_date: Date.today.iso8601 }
      }
      expect(response).to redirect_to(agreement_path)
      expect(payment.reload.paid_date).to eq(Date.today)
    end

    it "re-renders the agreement page with errors on invalid data" do
      patch property_rental_agreement_payment_path(property, agreement, payment), params: {
        payment: { amount: "-5" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "cannot update another landlord's payment" do
      other_payment = create(:payment)
      other_agreement = other_payment.rental_agreement
      expect {
        patch property_rental_agreement_payment_path(other_agreement.property, other_agreement, other_payment),
              params: { payment: { amount: "1" } }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "cannot reach a payment through an agreement it does not belong to" do
      foreign_payment = create(:payment)
      expect {
        patch property_rental_agreement_payment_path(property, agreement, foreign_payment),
              params: { payment: { amount: "1" } }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE /properties/:pid/rental_agreements/:aid/payments/:id" do
    let!(:payment) { create(:payment, rental_agreement: agreement) }

    it "destroys the payment and redirects to the agreement" do
      expect {
        delete property_rental_agreement_payment_path(property, agreement, payment)
      }.to change(agreement.payments, :count).by(-1)
      expect(response).to redirect_to(agreement_path)
    end

    it "cannot destroy another landlord's payment" do
      other_payment = create(:payment)
      other_agreement = other_payment.rental_agreement
      expect {
        delete property_rental_agreement_payment_path(other_agreement.property, other_agreement, other_payment)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
