class ExpensesController < ApplicationController
  include PropertyShowLoadable

  before_action :set_property
  before_action :set_expense, only: [:edit, :update, :destroy, :document]
  before_action -> { redirect_unless_turbo_frame_request(property_path(@property)) }, only: [:edit]

  def create
    @expense = @property.expenses.build(expense_params)
    if @expense.save
      redirect_to property_path(@property)
    else
      load_property_show_data
      @new_expense = @expense
      render template: "properties/show", status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      @expense.invoice_document.purge if remove_invoice_document_requested?
      redirect_to property_path(@property)
    else
      load_property_show_data
      @editing_expense = @expense
      render template: "properties/show", status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    redirect_to property_path(@property)
  end

  # Streams the stored invoice/receipt through the app, scoped to this
  # landlord's expense, rather than exposing a raw ActiveStorage URL — so the
  # file stays behind the tenancy boundary. Not plan-gated: it's the landlord's
  # own data, so a downgraded (free) landlord keeps read access.
  def document
    unless @expense.invoice_document.attached?
      redirect_to property_path(@property),
        alert: t("expenses.invoice_document.errors.missing")
      return
    end

    send_data @expense.invoice_document.download,
      filename: @expense.invoice_document.filename.to_s,
      content_type: @expense.invoice_document.content_type,
      disposition: "attachment"
  end

  private

  def set_expense
    @expense = @property.expenses.find(params[:id])
  end

  def expense_params
    permitted = [:date, :amount, :category, :description,
      :collectable, :deductible, :period_start, :period_end]
    # Attaching a stored document is a Pro+ capability; drop the param entirely
    # for other tiers so a crafted request can't slip a file past the gate.
    permitted << :invoice_document if current_landlord.expense_document_allowed?
    params.require(:expense).permit(*permitted)
  end

  def remove_invoice_document_requested?
    current_landlord.expense_document_allowed? &&
      params.dig(:expense, :remove_invoice_document) == "1" &&
      params.dig(:expense, :invoice_document).blank?
  end
end
