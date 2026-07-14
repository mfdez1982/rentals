require "rails_helper"

RSpec.describe RecollectionGenerator do
  let(:property) { create(:property) }

  def collectable_expense(period_start:, period_end:, amount:)
    create(:expense, :collectable, property: property, period_start: period_start, period_end: period_end, amount: amount)
  end

  describe "proration" do
    let(:expense) { collectable_expense(period_start: Date.new(2025, 3, 1), period_end: Date.new(2025, 3, 31), amount: 310.00) }

    it "prorates independently across agreements, leaving vacant days uncovered" do
      agreement_a = create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 3, 10))
      agreement_b = create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 21), end_date: Date.new(2025, 6, 30))

      slices = RecollectionGenerator.new(expense).preview
      expect(slices.size).to eq(2)

      slice_a = slices.find { |s| s.rental_agreement == agreement_a }
      slice_b = slices.find { |s| s.rental_agreement == agreement_b }

      expect(slice_a.overlap_days).to eq(10)
      expect(slice_a.amount).to eq(100.00)
      expect(slice_a.period_start).to eq(Date.new(2025, 3, 1))
      expect(slice_a.period_end).to eq(Date.new(2025, 3, 10))

      expect(slice_b.overlap_days).to eq(11)
      expect(slice_b.amount).to eq(110.00)
      expect(slice_b.period_start).to eq(Date.new(2025, 3, 21))
      expect(slice_b.period_end).to eq(Date.new(2025, 3, 31))
    end

    it "gives the full amount to an agreement that fully covers the expense period" do
      agreement = create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 3, 31))

      slice = RecollectionGenerator.new(expense).preview.first
      expect(slice.overlap_days).to eq(31)
      expect(slice.amount).to eq(310.00)
    end

    it "gives the full amount to an agreement that encloses the expense period" do
      agreement = create(:rental_agreement, property: property, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31))

      slice = RecollectionGenerator.new(expense).preview.first
      expect(slice.overlap_days).to eq(31)
      expect(slice.amount).to eq(310.00)
    end

    it "sorts slices by agreement start_date" do
      later = create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 21), end_date: Date.new(2025, 6, 30))
      earlier = create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 3, 10))

      slices = RecollectionGenerator.new(expense).preview
      expect(slices.map(&:rental_agreement)).to eq([ earlier, later ])
    end
  end

  describe "rounding" do
    it "splits an amount across 3 accepted tenants using largest-remainder cents, summing exactly" do
      expense = collectable_expense(period_start: Date.new(2025, 3, 1), period_end: Date.new(2025, 3, 31), amount: 100.00)
      agreement = create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 3, 31))
      3.times { create(:agreement_tenant, :accepted, rental_agreement: agreement) }

      slice = RecollectionGenerator.new(expense).preview.first
      amounts = slice.suggested_shares.map(&:amount)

      expect(amounts).to eq([ 33.34, 33.33, 33.33 ])
      expect(amounts.sum.round(2)).to eq(100.00)
    end

    it "rounds slice proration to cents" do
      expense = collectable_expense(period_start: Date.new(2025, 1, 1), period_end: Date.new(2025, 1, 31), amount: 100.00)
      agreement = create(:rental_agreement, property: property, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 1, 10))

      slice = RecollectionGenerator.new(expense).preview.first
      # 100 * 10 / 31 = 32.258... => 32.26
      expect(slice.amount).to eq(32.26)
    end
  end

  describe "independence" do
    it "leaves an earlier agreement's computed slice unchanged when a later agreement is added" do
      expense = collectable_expense(period_start: Date.new(2025, 3, 1), period_end: Date.new(2025, 3, 31), amount: 310.00)
      agreement_a = create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 3, 10))

      first_pass = RecollectionGenerator.new(expense).preview
      expect(first_pass.size).to eq(1)
      expect(first_pass.first.amount).to eq(100.00)

      agreement_b = create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 21), end_date: Date.new(2025, 6, 30))

      second_pass = RecollectionGenerator.new(expense).preview
      slice_a = second_pass.find { |s| s.rental_agreement == agreement_a }
      slice_b = second_pass.find { |s| s.rental_agreement == agreement_b }

      expect(slice_a.amount).to eq(100.00)
      expect(slice_b.amount).to eq(110.00)
    end
  end

  describe "idempotency" do
    it "excludes agreements with existing recollections from preview, and re-running generate! creates nothing" do
      expense = collectable_expense(period_start: Date.new(2025, 3, 1), period_end: Date.new(2025, 3, 31), amount: 310.00)
      agreement = create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 3, 31))

      generator = RecollectionGenerator.new(expense)
      slice = generator.preview.first
      params = [ { rental_agreement_id: agreement.id, shares: slice.suggested_shares.map { |s| { agreement_tenant_id: s.agreement_tenant&.id, amount: s.amount } } } ]

      result = generator.generate!(params)
      expect(result.outcome).to eq(:success)
      expect(result.recollections.size).to eq(1)

      expect(RecollectionGenerator.new(expense).preview).to be_empty

      second_result = RecollectionGenerator.new(expense).generate!(params)
      expect(second_result.outcome).to eq(:nothing_to_generate)
      expect(Recollection.where(expense: expense).count).to eq(1)
    end
  end

  describe "two-zeros distinction" do
    it "is a hard error when no agreement overlaps the period at all" do
      expense = collectable_expense(period_start: Date.new(2025, 3, 1), period_end: Date.new(2025, 3, 31), amount: 310.00)
      create(:rental_agreement, property: property, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 2, 28))

      generator = RecollectionGenerator.new(expense)
      expect(generator.no_overlapping_agreements?).to be true
      expect(generator.preview).to be_empty

      result = generator.generate!([ { rental_agreement_id: 999, shares: [] } ])
      expect(result.outcome).to eq(:no_overlapping_agreements)
      expect(Recollection.count).to eq(0)
    end

    it "is fine for an overlapping agreement with zero accepted tenants: one recollection with no payer" do
      expense = collectable_expense(period_start: Date.new(2025, 3, 1), period_end: Date.new(2025, 3, 31), amount: 310.00)
      agreement = create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 3, 31))

      generator = RecollectionGenerator.new(expense)
      expect(generator.no_overlapping_agreements?).to be false

      slice = generator.preview.first
      expect(slice.suggested_shares.size).to eq(1)
      expect(slice.suggested_shares.first.agreement_tenant).to be_nil
      expect(slice.suggested_shares.first.amount).to eq(310.00)

      result = generator.generate!([ { rental_agreement_id: agreement.id, shares: [ { agreement_tenant_id: nil, amount: 310.00 } ] } ])
      expect(result.outcome).to eq(:success)
      expect(result.recollections.size).to eq(1)
      expect(result.recollections.first.agreement_tenant).to be_nil
    end
  end

  describe "#generate! persistence and overrides" do
    it "persists landlord-overridden amounts and a due_date, and nils out a blank agreement_tenant_id" do
      expense = collectable_expense(period_start: Date.new(2025, 3, 1), period_end: Date.new(2025, 3, 31), amount: 310.00)
      agreement = create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 3, 31))

      params = [ {
        rental_agreement_id: agreement.id,
        due_date: Date.new(2025, 4, 15),
        shares: [ { agreement_tenant_id: "", amount: 250.50 } ]
      } ]

      result = RecollectionGenerator.new(expense).generate!(params)
      expect(result.outcome).to eq(:success)
      recollection = result.recollections.first
      expect(recollection.amount).to eq(250.50)
      expect(recollection.due_date).to eq(Date.new(2025, 4, 15))
      expect(recollection.agreement_tenant).to be_nil
    end

    it "rolls back everything when a share amount is invalid" do
      expense = collectable_expense(period_start: Date.new(2025, 3, 1), period_end: Date.new(2025, 3, 31), amount: 310.00)
      agreement_a = create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 3, 10))
      agreement_b = create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 21), end_date: Date.new(2025, 3, 31))

      params = [
        { rental_agreement_id: agreement_a.id, shares: [ { agreement_tenant_id: nil, amount: 100.00 } ] },
        { rental_agreement_id: agreement_b.id, shares: [ { agreement_tenant_id: nil, amount: 0 } ] }
      ]

      result = RecollectionGenerator.new(expense).generate!(params)
      expect(result.outcome).to eq(:invalid)
      expect(Recollection.count).to eq(0)
    end
  end

  describe "non-collectable expense" do
    it "returns :not_collectable" do
      expense = create(:expense, property: property, amount: 100.00)
      result = RecollectionGenerator.new(expense).generate!([])
      expect(result.outcome).to eq(:not_collectable)
      expect(RecollectionGenerator.new(expense).preview).to eq([])
    end
  end

  describe "cross-property safety" do
    it "skips a slice whose rental_agreement_id belongs to another property" do
      expense = collectable_expense(period_start: Date.new(2025, 3, 1), period_end: Date.new(2025, 3, 31), amount: 310.00)
      create(:rental_agreement, property: property, start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 3, 31))

      other_property = create(:property)
      other_agreement = create(:rental_agreement, property: other_property, start_date: Date.new(2025, 3, 1), end_date: Date.new(2025, 3, 31))

      params = [ { rental_agreement_id: other_agreement.id, shares: [ { agreement_tenant_id: nil, amount: 50.00 } ] } ]

      result = RecollectionGenerator.new(expense).generate!(params)
      expect(result.outcome).to eq(:nothing_to_generate)
      expect(Recollection.count).to eq(0)
    end
  end
end
