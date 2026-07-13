require "rails_helper"

RSpec.describe Expense, type: :model do
  describe "validations" do
    it "is valid with the factory defaults" do
      expect(build(:expense)).to be_valid
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

  describe "categories" do
    it "exposes the expected enum keys" do
      expect(Expense.categories.keys).to contain_exactly(
        "tax", "insurance", "utilities", "community_fees",
        "repairs_maintenance", "management_legal", "financing", "other"
      )
    end
  end
end
