require "rails_helper"

RSpec.describe Expense, type: :model do
  describe "validations" do
    it "is valid with the factory defaults" do
      expect(build(:expense)).to be_valid
    end

    it "defaults deductible to true" do
      expect(build(:expense).deductible).to eq(true)
      expect(create(:expense).deductible).to eq(true)
    end

    it "requires date, amount and category" do
      expect(build(:expense, date: nil)).not_to be_valid
      expect(build(:expense, amount: nil)).not_to be_valid
      expect(build(:expense, category: nil)).not_to be_valid
    end

    it "rejects a zero or negative amount" do
      expect(build(:expense, amount: 0)).not_to be_valid
      expect(build(:expense, amount: -1)).not_to be_valid
    end

    describe "invoice_url format" do
      it "allows blank" do
        expect(build(:expense, invoice_url: "")).to be_valid
        expect(build(:expense, invoice_url: nil)).to be_valid
      end

      it "allows http and https URLs" do
        expect(build(:expense, invoice_url: "https://example.com/invoice.pdf")).to be_valid
        expect(build(:expense, invoice_url: "http://example.com/x")).to be_valid
      end

      it "rejects non-http URLs and plain text" do
        expect(build(:expense, invoice_url: "ftp://example.com/x")).not_to be_valid
        expect(build(:expense, invoice_url: "not a url")).not_to be_valid
      end
    end
  end

  describe "scopes" do
    it "returns only expenses that are both collectable and deductible" do
      both = create(:expense, :collectable, deductible: true)
      collectable_only = create(:expense, :collectable, deductible: false)
      deductible_only = create(:expense, deductible: true, collectable: false)

      result = Expense.collectable.deductible
      expect(result).to include(both)
      expect(result).not_to include(collectable_only, deductible_only)
    end
  end

  describe "categories" do
    it "exposes the expected enum keys" do
      expect(Expense.categories.keys).to contain_exactly(
        "tax", "insurance", "utilities", "community_fees",
        "repairs_maintenance", "management_legal", "financing", "other"
      )
    end
  end

  describe "collectable periods" do
    it "requires period_start and period_end when collectable" do
      expect(build(:expense, :collectable, period_start: nil)).not_to be_valid
      expect(build(:expense, :collectable, period_end: nil)).not_to be_valid
    end

    it "rejects a period_end before period_start when collectable" do
      expense = build(:expense, :collectable,
                       period_start: Date.new(2025, 6, 30), period_end: Date.new(2025, 6, 1))
      expect(expense).not_to be_valid
      expect(expense.errors[:period_end]).to be_present
    end

    it "accepts a period_end equal to period_start when collectable" do
      expense = build(:expense, :collectable,
                       period_start: Date.new(2025, 6, 15), period_end: Date.new(2025, 6, 15))
      expect(expense).to be_valid
    end

    it "does not require periods when not collectable" do
      expense = build(:expense, collectable: false, period_start: nil, period_end: nil)
      expect(expense).to be_valid
    end
  end

  describe "#period_days" do
    it "counts inclusively" do
      expense = build(:expense, period_start: Date.new(2025, 3, 1), period_end: Date.new(2025, 3, 31))
      expect(expense.period_days).to eq(31)
    end

    it "is nil when either date is missing" do
      expect(build(:expense, period_start: nil, period_end: Date.today).period_days).to be_nil
      expect(build(:expense, period_start: Date.today, period_end: nil).period_days).to be_nil
      expect(build(:expense, period_start: nil, period_end: nil).period_days).to be_nil
    end
  end
end
