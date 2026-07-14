require "rails_helper"

RSpec.describe Recollection, type: :model do
  let(:property) { create(:property) }
  let(:expense) do
    create(:expense, :collectable, property: property,
           period_start: Date.new(2025, 6, 1), period_end: Date.new(2025, 6, 30))
  end
  let(:rental_agreement) do
    create(:rental_agreement, property: property,
           start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31))
  end

  describe "validations" do
    it "is valid with the factory defaults" do
      expect(build(:recollection)).to be_valid
    end

    it "requires an amount" do
      recollection = build(:recollection, amount: nil)
      expect(recollection).not_to be_valid
    end

    it "rejects a zero or negative amount" do
      expect(build(:recollection, amount: 0)).not_to be_valid
      expect(build(:recollection, amount: -10)).not_to be_valid
    end

    it "requires period_start and period_end" do
      expect(build(:recollection, period_start: nil)).not_to be_valid
      expect(build(:recollection, period_end: nil)).not_to be_valid
    end

    it "rejects a period_end before period_start" do
      recollection = build(:recollection, expense: expense, rental_agreement: rental_agreement,
                            period_start: Date.new(2025, 6, 30), period_end: Date.new(2025, 6, 1))
      expect(recollection).not_to be_valid
      expect(recollection.errors[:period_end]).to be_present
    end

    it "accepts a period_end equal to period_start" do
      recollection = build(:recollection, expense: expense, rental_agreement: rental_agreement,
                            period_start: Date.new(2025, 6, 15), period_end: Date.new(2025, 6, 15))
      expect(recollection).to be_valid
    end

    it "rejects a rental_agreement on a different property than the expense" do
      other_agreement = create(:rental_agreement)
      recollection = build(:recollection, expense: expense, rental_agreement: other_agreement,
                            period_start: expense.period_start, period_end: expense.period_end)
      expect(recollection).not_to be_valid
      expect(recollection.errors[:rental_agreement]).to be_present
    end

    it "rejects an agreement_tenant belonging to a different rental_agreement" do
      other_agreement = create(:rental_agreement, property: property,
                                start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31))
      other_tenant = create(:agreement_tenant, :accepted, rental_agreement: other_agreement)

      recollection = build(:recollection, expense: expense, rental_agreement: rental_agreement,
                            agreement_tenant: other_tenant,
                            period_start: expense.period_start, period_end: expense.period_end)
      expect(recollection).not_to be_valid
      expect(recollection.errors[:agreement_tenant]).to be_present
    end

    it "accepts an agreement_tenant that belongs to the same rental_agreement" do
      tenant = create(:agreement_tenant, :accepted, rental_agreement: rental_agreement)
      recollection = build(:recollection, expense: expense, rental_agreement: rental_agreement,
                            agreement_tenant: tenant,
                            period_start: expense.period_start, period_end: expense.period_end)
      expect(recollection).to be_valid
    end

    it "allows a nil agreement_tenant (no payer assigned)" do
      recollection = build(:recollection, expense: expense, rental_agreement: rental_agreement,
                            agreement_tenant: nil,
                            period_start: expense.period_start, period_end: expense.period_end)
      expect(recollection).to be_valid
    end
  end

  describe "#property" do
    it "delegates to the expense's property" do
      recollection = build(:recollection, expense: expense, rental_agreement: rental_agreement,
                            period_start: expense.period_start, period_end: expense.period_end)
      expect(recollection.property).to eq(property)
    end
  end

  describe "enums" do
    it "has pending and paid statuses" do
      expect(Recollection.statuses).to eq("pending" => 0, "paid" => 1)
    end

    it "defaults to pending" do
      expect(Recollection.new.status).to eq("pending")
    end
  end

  describe "#overdue?" do
    it "is overdue when pending and due in the past" do
      recollection = build(:recollection, status: :pending, due_date: Date.yesterday)
      expect(recollection).to be_overdue
    end

    it "is not overdue when paid, even after the due date" do
      recollection = build(:recollection, status: :paid, due_date: Date.yesterday, paid_date: Date.today)
      expect(recollection).not_to be_overdue
    end

    it "is not overdue when there is no due_date" do
      recollection = build(:recollection, status: :pending, due_date: nil)
      expect(recollection).not_to be_overdue
    end

    it "is not overdue when due in the future" do
      recollection = build(:recollection, status: :pending, due_date: Date.tomorrow)
      expect(recollection).not_to be_overdue
    end
  end

  describe ".overdue scope" do
    it "includes only pending recollections with a past due_date" do
      overdue = create(:recollection, :overdue)
      create(:recollection, :paid, due_date: Date.yesterday)
      create(:recollection, due_date: Date.tomorrow)
      create(:recollection, due_date: nil)

      expect(Recollection.overdue).to contain_exactly(overdue)
    end
  end

  describe "dependent behavior" do
    it "nullifies agreement_tenant_id when the agreement_tenant is destroyed" do
      recollection = create(:recollection, :with_tenant)
      tenant = recollection.agreement_tenant
      tenant.destroy
      expect(recollection.reload.agreement_tenant_id).to be_nil
    end

    it "restricts destroying a rental_agreement that has recollections" do
      recollection = create(:recollection)
      agreement = recollection.rental_agreement
      expect { agreement.destroy }.not_to change(Recollection, :count)
      expect(agreement.errors[:base]).to be_present
    end

    it "restricts destroying an expense that has recollections" do
      recollection = create(:recollection)
      exp = recollection.expense
      expect { exp.destroy }.not_to change(Recollection, :count)
      expect(exp.errors[:base]).to be_present
    end
  end
end
