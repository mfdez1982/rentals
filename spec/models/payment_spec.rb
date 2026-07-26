require "rails_helper"

RSpec.describe Payment, type: :model do
  describe "validations" do
    it "requires a due date" do
      payment = build(:payment, due_date: nil)
      expect(payment).not_to be_valid
      expect(payment.errors[:due_date]).to be_present
    end

    it "requires an amount" do
      payment = build(:payment, amount: nil)
      expect(payment).not_to be_valid
    end

    it "rejects a zero or negative amount" do
      expect(build(:payment, amount: 0)).not_to be_valid
      expect(build(:payment, amount: -10)).not_to be_valid
    end
  end

  describe "#overdue?" do
    it "is overdue when unpaid and due in the past" do
      expect(build(:payment, due_date: Date.yesterday, paid_date: nil)).to be_overdue
    end

    it "is not overdue when paid, even after the due date" do
      expect(build(:payment, due_date: Date.yesterday, paid_date: Date.today)).not_to be_overdue
    end

    it "is not overdue when due today" do
      expect(build(:payment, due_date: Date.today, paid_date: nil)).not_to be_overdue
    end

    it "is not overdue when due in the future" do
      expect(build(:payment, due_date: Date.tomorrow, paid_date: nil)).not_to be_overdue
    end
  end

  describe "#reminder_due?" do
    let(:interval) { 7.days }

    it "is due when overdue and never reminded" do
      payment = build(:payment, due_date: Date.yesterday, last_reminded_at: nil)
      expect(payment.reminder_due?(interval: interval)).to be(true)
    end

    it "is not due when not overdue, even if never reminded" do
      payment = build(:payment, due_date: Date.tomorrow, last_reminded_at: nil)
      expect(payment.reminder_due?(interval: interval)).to be(false)
    end

    it "is not due when reminded within the interval" do
      payment = build(:payment, due_date: 30.days.ago, last_reminded_at: 2.days.ago)
      expect(payment.reminder_due?(interval: interval)).to be(false)
    end

    it "is due again once the last reminder is older than the interval" do
      payment = build(:payment, due_date: 30.days.ago, last_reminded_at: 8.days.ago)
      expect(payment.reminder_due?(interval: interval)).to be(true)
    end
  end
end
