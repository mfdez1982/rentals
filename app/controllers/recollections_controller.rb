class RecollectionsController < ApplicationController
  include PropertyShowLoadable

  before_action :set_property
  before_action :set_expense, only: [:new, :create]
  before_action :set_recollection, only: [:destroy, :mark_paid]

  def new
    unless @expense.collectable?
      redirect_to property_path(@property), alert: t("recollections.not_collectable") and return
    end

    @generator = RecollectionGenerator.new(@expense)
    @preview = @generator.preview
  end

  def create
    unless @expense.collectable?
      redirect_to property_path(@property), alert: t("recollections.not_collectable") and return
    end

    generator = RecollectionGenerator.new(@expense)
    result = generator.generate!(filtered_slices_params)

    case result.outcome
    when :success
      redirect_to property_path(@property),
        notice: t("recollections.created", count: result.recollections.size)
    when :no_overlapping_agreements
      redirect_to property_path(@property), alert: t("recollections.no_overlapping_agreements")
    when :not_collectable
      redirect_to property_path(@property), alert: t("recollections.not_collectable")
    when :nothing_to_generate
      redirect_to property_path(@property), alert: t("recollections.nothing_to_generate")
    when :invalid
      @generator = generator
      @preview = generator.preview
      @recollection_errors = result.errors
      render :new, status: :unprocessable_entity
    end
  end

  def mark_paid
    @recollection.update(status: :paid, paid_date: Date.today)
    redirect_to property_path(@property), notice: t("recollections.marked_paid")
  end

  def destroy
    @recollection.destroy
    redirect_to property_path(@property), notice: t("recollections.deleted")
  end

  private

  def set_expense
    @expense = @property.expenses.find(params[:expense_id])
  end

  def set_recollection
    @recollection = @property.recollections.find(params[:id])
  end

  # Strips out unchecked shares before handing the params to the generator,
  # per the "Recollect" flow's include-checkbox semantics. Built from
  # to_unsafe_h/values rather than relying on params[:slices] being parsed
  # as an Array, since Rails parses bracket-indexed form params ("slices[0][...]")
  # into a Hash keyed by index string, not an Array.
  def filtered_slices_params
    raw = params[:slices]
    return [] if raw.blank?

    raw.to_unsafe_h.values.map do |raw_slice|
      slice = ActionController::Parameters.new(raw_slice)
                .permit(:rental_agreement_id, :due_date, shares: [:agreement_tenant_id, :include, :amount])
                .to_h
      shares = slice["shares"]
      shares = shares.is_a?(Hash) ? shares.values : Array(shares)
      slice["shares"] = shares.select { |s| s["include"] == "1" }
      slice
    end
  end
end
