require "rails_helper"

RSpec.describe RentalAgreement, type: :model do
  let(:property) { create(:property) }

  def agreement(start_on, end_on, **attrs)
    build(:rental_agreement, property: property,
          start_date: start_on, end_date: end_on, **attrs)
  end

  describe "validations" do
    it "requires start date, end date and rent amount" do
      expect(build(:rental_agreement, start_date: nil)).not_to be_valid
      expect(build(:rental_agreement, end_date: nil)).not_to be_valid
      expect(build(:rental_agreement, rent_amount: nil)).not_to be_valid
    end

    it "rejects a zero or negative rent" do
      expect(build(:rental_agreement, rent_amount: 0)).not_to be_valid
      expect(build(:rental_agreement, rent_amount: -1)).not_to be_valid
    end

    it "rejects an end date on or before the start date" do
      expect(agreement(Date.new(2025, 1, 1), Date.new(2025, 1, 1))).not_to be_valid
      expect(agreement(Date.new(2025, 1, 2), Date.new(2025, 1, 1))).not_to be_valid
    end

    describe "overlap with other agreements on the same property" do
      let!(:existing) do
        create(:rental_agreement, property: property,
               start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31))
      end

      it "rejects an agreement fully inside an existing one" do
        expect(agreement(Date.new(2025, 3, 1), Date.new(2025, 6, 30))).not_to be_valid
      end

      it "rejects an agreement sharing a boundary day (inclusive overlap)" do
        expect(agreement(Date.new(2025, 12, 31), Date.new(2026, 6, 30))).not_to be_valid
      end

      it "accepts an agreement starting the day after the existing one ends (renewal)" do
        expect(agreement(Date.new(2026, 1, 1), Date.new(2026, 12, 31))).to be_valid
      end

      it "accepts overlapping dates on a different property" do
        other = build(:rental_agreement,
                      start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 6, 30))
        expect(other).to be_valid
      end

      it "does not report an agreement as overlapping itself on update" do
        existing.rent_amount = 123
        expect(existing).to be_valid
      end
    end
  end

  describe "status predicates and scopes" do
    let!(:active)   { create(:rental_agreement, property: property, start_date: 1.month.ago.to_date, end_date: 1.month.from_now.to_date) }
    let!(:upcoming) { create(:rental_agreement, property: property, start_date: 2.months.from_now.to_date, end_date: 4.months.from_now.to_date) }
    let!(:expired)  { create(:rental_agreement, property: property, start_date: 1.year.ago.to_date, end_date: 2.months.ago.to_date) }

    it "classifies each agreement" do
      expect(active).to be_active
      expect(active).not_to be_expired
      expect(upcoming).to be_upcoming
      expect(expired).to be_expired
    end

    it "scopes match the predicates" do
      expect(property.rental_agreements.active).to contain_exactly(active)
      expect(property.rental_agreements.upcoming).to contain_exactly(upcoming)
      expect(property.rental_agreements.expired).to contain_exactly(expired)
    end

    it "sorts by start date, newest first" do
      expect(property.rental_agreements.sorted.to_a).to eq([upcoming, active, expired])
    end

    it "treats boundary days as active (inclusive range)" do
      boundary = build(:rental_agreement, start_date: Date.today, end_date: Date.today + 1)
      expect(boundary).to be_active
    end
  end

  describe ".overlapping" do
    let!(:mid) do
      create(:rental_agreement, property: property,
             start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 6, 30))
    end

    it "matches an agreement whose window overlaps the given range" do
      expect(property.rental_agreements.overlapping(Date.new(2025, 6, 1), Date.new(2025, 12, 31)))
        .to contain_exactly(mid)
    end

    it "excludes an agreement whose window does not overlap" do
      expect(property.rental_agreements.overlapping(Date.new(2025, 7, 1), Date.new(2025, 12, 31)))
        .to be_empty
    end

    it "includes an agreement that only touches the range at a boundary day" do
      expect(property.rental_agreements.overlapping(Date.new(2025, 6, 30), Date.new(2025, 12, 31)))
        .to contain_exactly(mid)
      expect(property.rental_agreements.overlapping(Date.new(2025, 1, 1), Date.new(2025, 3, 1)))
        .to contain_exactly(mid)
    end
  end

  describe "#clamped_range and #days_within" do
    let(:contract) { agreement(Date.new(2025, 3, 1), Date.new(2025, 6, 30)) }

    it "returns the full agreement range when fully contained in the window" do
      range = contract.clamped_range(Date.new(2025, 1, 1), Date.new(2025, 12, 31))
      expect(range).to eq(Date.new(2025, 3, 1)..Date.new(2025, 6, 30))
      expect(contract.days_within(Date.new(2025, 1, 1), Date.new(2025, 12, 31))).to eq(122)
    end

    it "clamps the start when the window begins after the agreement starts" do
      range = contract.clamped_range(Date.new(2025, 4, 1), Date.new(2025, 12, 31))
      expect(range).to eq(Date.new(2025, 4, 1)..Date.new(2025, 6, 30))
      expect(contract.days_within(Date.new(2025, 4, 1), Date.new(2025, 12, 31))).to eq(91)
    end

    it "clamps the end when the window ends before the agreement ends" do
      range = contract.clamped_range(Date.new(2025, 1, 1), Date.new(2025, 5, 15))
      expect(range).to eq(Date.new(2025, 3, 1)..Date.new(2025, 5, 15))
      expect(contract.days_within(Date.new(2025, 1, 1), Date.new(2025, 5, 15))).to eq(76)
    end

    it "returns nil / 0 when the window does not overlap the agreement at all" do
      range = contract.clamped_range(Date.new(2025, 7, 1), Date.new(2025, 12, 31))
      expect(range).to be_nil
      expect(contract.days_within(Date.new(2025, 7, 1), Date.new(2025, 12, 31))).to eq(0)
    end
  end

  describe "#has_overdue_payments?" do
    let(:contract) { create(:rental_agreement, property: property, start_date: 1.year.ago.to_date, end_date: 1.year.from_now.to_date) }

    it "is true when any payment is overdue" do
      create(:payment, rental_agreement: contract, due_date: 1.month.ago.to_date, paid_date: nil)
      expect(contract.has_overdue_payments?).to be true
    end

    it "is false when all payments are paid or not yet due" do
      create(:payment, rental_agreement: contract, due_date: 1.month.ago.to_date, paid_date: 1.month.ago.to_date)
      create(:payment, rental_agreement: contract, due_date: 1.month.from_now.to_date, paid_date: nil)
      expect(contract.has_overdue_payments?).to be false
    end
  end

  describe "lease document" do
    let(:agreement) { build(:rental_agreement, property: property) }

    def attach(name, type)
      agreement.lease_document.attach(io: file_fixture(name).open, filename: name, content_type: type)
    end

    it "is valid without a lease document" do
      expect(agreement).to be_valid
    end

    it "accepts a PDF" do
      attach("lease.pdf", "application/pdf")
      expect(agreement).to be_valid
    end

    it "rejects a non-PDF file" do
      attach("not_a_pdf.txt", "text/plain")
      expect(agreement).not_to be_valid
      expect(agreement.errors[:lease_document]).to be_present
    end

    it "rejects a file over the size limit" do
      attach("lease.pdf", "application/pdf")
      allow(agreement.lease_document).to receive(:byte_size)
        .and_return(RentalAgreement::LEASE_DOCUMENT_MAX_BYTES + 1)
      expect(agreement).not_to be_valid
      expect(agreement.errors[:lease_document]).to be_present
    end
  end
end
