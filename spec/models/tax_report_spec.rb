require "rails_helper"

RSpec.describe TaxReport, type: :model do
  it "belongs to a property and is valid from the factory" do
    expect(build(:tax_report)).to be_valid
  end

  it "requires the core figures" do
    report = build(:tax_report, year: nil, total_gross_income: nil)
    expect(report).not_to be_valid
    expect(report.errors[:year]).to be_present
    expect(report.errors[:total_gross_income]).to be_present
  end

  it "cannot have its figures updated once persisted (immutable snapshot)" do
    report = create(:tax_report)
    expect { report.update!(year: 2099) }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "allows the name to be edited after creation" do
    report = create(:tax_report)
    expect { report.update!(name: "2026 filing") }.not_to raise_error
    expect(report.reload.name).to eq("2026 filing")
  end

  it "can still be destroyed" do
    report = create(:tax_report)
    expect { report.destroy }.to change(TaxReport, :count).by(-1)
  end

  it "sums the expense-line snapshot" do
    report = build(:tax_report, expense_lines: [
      { "original_amount" => "100.00", "deductible_amount" => "60.00" },
      { "original_amount" => "50.50", "deductible_amount" => "30.25" }
    ])
    expect(report.total_original_amount).to eq(150.50)
    expect(report.total_deductible_amount).to eq(90.25)
  end
end
