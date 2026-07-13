require "rails_helper"

RSpec.describe Property, type: :model do
  let(:property) { create(:property) }

  it "requires a name" do
    expect(build(:property, name: nil)).not_to be_valid
  end

  describe "#rented? / #active_rental_agreement" do
    it "is rented while an agreement covers today" do
      active = create(:rental_agreement, property: property,
                      start_date: 1.month.ago.to_date, end_date: 1.month.from_now.to_date)
      expect(property).to be_rented
      expect(property.active_rental_agreement).to eq(active)
    end

    it "is not rented with only expired or upcoming agreements" do
      create(:rental_agreement, property: property,
             start_date: 1.year.ago.to_date, end_date: 2.months.ago.to_date)
      create(:rental_agreement, property: property,
             start_date: 2.months.from_now.to_date, end_date: 6.months.from_now.to_date)
      expect(property).not_to be_rented
      expect(property.active_rental_agreement).to be_nil
    end
  end

  describe "#has_overdue_payments?" do
    it "is true when any agreement has an overdue payment" do
      agreement = create(:rental_agreement, property: property,
                         start_date: 1.year.ago.to_date, end_date: 1.year.from_now.to_date)
      create(:payment, rental_agreement: agreement, due_date: 1.week.ago.to_date, paid_date: nil)
      expect(property.has_overdue_payments?).to be true
    end

    it "is false without overdue payments" do
      agreement = create(:rental_agreement, property: property,
                         start_date: 1.year.ago.to_date, end_date: 1.year.from_now.to_date)
      create(:payment, rental_agreement: agreement, due_date: 1.week.ago.to_date, paid_date: Date.today)
      expect(property.has_overdue_payments?).to be false
    end
  end

  describe "#next_unpaid_payment" do
    it "returns the soonest unpaid payment across all agreements" do
      first = create(:rental_agreement, property: property,
                     start_date: 2.years.ago.to_date, end_date: 13.months.ago.to_date)
      second = create(:rental_agreement, property: property,
                      start_date: 1.year.ago.to_date, end_date: 1.year.from_now.to_date)
      create(:payment, rental_agreement: first, due_date: 18.months.ago.to_date, paid_date: 18.months.ago.to_date)
      old_unpaid = create(:payment, rental_agreement: first, due_date: 14.months.ago.to_date, paid_date: nil)
      create(:payment, rental_agreement: second, due_date: 1.month.from_now.to_date, paid_date: nil)

      expect(property.next_unpaid_payment).to eq(old_unpaid)
    end

    it "is nil when every payment is paid" do
      agreement = create(:rental_agreement, property: property,
                         start_date: 1.year.ago.to_date, end_date: 1.year.from_now.to_date)
      create(:payment, rental_agreement: agreement, due_date: 1.month.ago.to_date, paid_date: Date.today)
      expect(property.next_unpaid_payment).to be_nil
    end
  end

  describe "#earliest_tax_year" do
    it "is the current year when there is no data" do
      expect(property.earliest_tax_year).to eq(Date.today.year)
    end

    it "is the earliest year across agreements and expenses" do
      create(:rental_agreement, property: property,
             start_date: Date.new(2024, 6, 1), end_date: Date.new(2025, 5, 31))
      create(:expense, property: property, date: Date.new(2023, 3, 15))
      expect(property.earliest_tax_year).to eq(2023)
    end
  end

  describe "dependent destroy" do
    it "removes agreements, payments, expenses and notes with the property" do
      agreement = create(:rental_agreement, property: property)
      create(:payment, rental_agreement: agreement)
      create(:expense, property: property)
      create(:note, landlord: property.landlord, noteable: property)

      expect { property.destroy }
        .to change(RentalAgreement, :count).by(-1)
        .and change(Payment, :count).by(-1)
        .and change(Expense, :count).by(-1)
        .and change(Note, :count).by(-1)
    end
  end
end
