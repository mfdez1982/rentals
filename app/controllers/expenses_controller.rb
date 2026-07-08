class ExpensesController < ApplicationController
  before_action :set_property
  before_action :set_expense, only: [:edit, :update, :destroy]
  before_action -> { redirect_unless_turbo_frame_request(property_path(@property)) }, only: [:edit]

  def create
    @expense = @property.expenses.build(expense_params)
    if @expense.save
      redirect_to property_path(@property)
    else
      @agreements = @property.rental_agreements.sorted
      @new_agreement = @property.rental_agreements.build
      @expenses = @property.expenses.order(date: :desc)
      @new_expense = @expense
      render template: "properties/show", status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      redirect_to property_path(@property)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    redirect_to property_path(@property)
  end

  private

  def set_property
    @property = current_landlord.properties.find(params[:property_id])
  end

  def set_expense
    @expense = @property.expenses.find(params[:id])
  end

  def expense_params
    params.require(:expense).permit(:date, :amount, :category, :description, :invoice_url)
  end
end
