# Computes and creates Recollection rows that prorate a collectable Expense
# across the RentalAgreements of its property that overlap the expense's
# period, and (optionally) splits each agreement's slice across its accepted
# tenants.
#
# Usage:
#   generator = RecollectionGenerator.new(expense)
#   generator.no_overlapping_agreements? # => true/false
#   generator.preview                    # => [Slice, ...] for eligible agreements
#   result = generator.generate!(slices_params)
#   result.success?      # => true/false
#   result.outcome        # => :success / :not_collectable / :no_overlapping_agreements / :nothing_to_generate
#   result.recollections  # => created Recollection records (empty unless :success)
#
# Idempotency: an agreement that already has any Recollection for this expense
# is excluded from #preview and skipped (not touched) by #generate!.
class RecollectionGenerator
  Slice = Struct.new(:rental_agreement, :period_start, :period_end, :overlap_days, :amount, :suggested_shares, keyword_init: true)
  Share = Struct.new(:agreement_tenant, :amount, keyword_init: true)
  Result = Struct.new(:outcome, :recollections, :errors, keyword_init: true) do
    def success?
      outcome == :success
    end
  end

  def initialize(expense)
    @expense = expense
  end

  def preview
    return [] unless expense.collectable?

    eligible_agreements.map { |agreement| build_slice(agreement) }
                        .sort_by { |slice| slice.rental_agreement.start_date }
  end

  def no_overlapping_agreements?
    overlapping_agreements(all_property_agreements).none?
  end

  def generate!(slices_params)
    return Result.new(outcome: :not_collectable, recollections: [], errors: nil) unless expense.collectable?
    return Result.new(outcome: :no_overlapping_agreements, recollections: [], errors: nil) if no_overlapping_agreements?

    eligible_ids = eligible_agreements.index_by(&:id)
    created = []

    ActiveRecord::Base.transaction do
      Array(slices_params).each do |raw_slice_params|
        slice_params = indifferent(raw_slice_params)
        agreement = eligible_ids[slice_params[:rental_agreement_id].to_i]
        next unless agreement

        slice = build_slice(agreement)
        due_date = slice_params[:due_date].presence

        shares = Array(slice_params[:shares])
        shares = [ { agreement_tenant_id: nil, amount: slice.amount } ] if shares.blank?

        shares.each do |raw_share_params|
          share_params = indifferent(raw_share_params)
          agreement_tenant_id = share_params[:agreement_tenant_id].presence

          recollection = Recollection.create!(
            expense: expense,
            rental_agreement: agreement,
            agreement_tenant_id: agreement_tenant_id,
            amount: share_params[:amount],
            due_date: due_date,
            period_start: slice.period_start,
            period_end: slice.period_end,
            status: :pending
          )
          created << recollection
        end
      end

      raise ActiveRecord::Rollback if created.empty?
    end

    if created.empty?
      Result.new(outcome: :nothing_to_generate, recollections: [], errors: nil)
    else
      Result.new(outcome: :success, recollections: created, errors: nil)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(outcome: :invalid, recollections: [], errors: e.record.errors)
  end

  private

  attr_reader :expense

  def indifferent(hash)
    hash.is_a?(Hash) ? hash.with_indifferent_access : hash
  end

  def property
    expense.property
  end

  def all_property_agreements
    property.rental_agreements
  end

  def overlapping_agreements(scope)
    scope.where("start_date <= ? AND end_date >= ?", expense.period_end, expense.period_start)
  end

  def agreements_without_existing_recollections(scope)
    scope.where.not(id: expense.recollections.select(:rental_agreement_id))
  end

  def eligible_agreements
    agreements_without_existing_recollections(overlapping_agreements(all_property_agreements))
  end

  def build_slice(agreement)
    period_start = [ expense.period_start, agreement.start_date ].max
    period_end = [ expense.period_end, agreement.end_date ].min
    overlap_days = (period_end - period_start).to_i + 1
    amount = (expense.amount * overlap_days / expense.period_days).round(2)

    Slice.new(
      rental_agreement: agreement,
      period_start: period_start,
      period_end: period_end,
      overlap_days: overlap_days,
      amount: amount,
      suggested_shares: suggested_shares(agreement, amount)
    )
  end

  def suggested_shares(agreement, slice_amount)
    tenants = agreement.accepted_agreement_tenants.order(:id)

    if tenants.empty?
      return [ Share.new(agreement_tenant: nil, amount: slice_amount) ]
    end

    split_amounts(slice_amount, tenants.size).each_with_index.map do |amount, index|
      Share.new(agreement_tenant: tenants[index], amount: amount)
    end
  end

  # Largest-remainder method: divide into equal cent amounts, then
  # distribute the leftover cents (from truncation) one-by-one, in order,
  # to the shares with the largest fractional remainder, so the amounts
  # sum exactly to total.
  def split_amounts(total, count)
    total_cents = (total * 100).round
    base_cents, remainder = total_cents.divmod(count)

    cents = Array.new(count, base_cents)
    remainder.times { |i| cents[i] += 1 }

    cents.map { |c| (c / 100.0).round(2) }
  end
end
