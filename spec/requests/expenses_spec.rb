require "rails_helper"

RSpec.describe "Expenses", type: :request do
  let(:user) { create(:user) }
  let(:landlord) { user.landlord }
  let(:property) { create(:property, landlord: landlord) }

  before { sign_in user }

  describe "POST /properties/:property_id/expenses" do
    it "creates an expense and redirects to the property" do
      post property_expenses_path(property), params: {
        expense: { date: "2026-07-01", amount: "500.00", category: "insurance", description: "Policy renewal" }
      }
      expect(response).to redirect_to(property_path(property))
      expect(property.expenses.count).to eq(1)
    end

    it "renders the property show with errors on invalid data" do
      post property_expenses_path(property), params: {
        expense: { date: "", amount: "-1", category: "tax" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "cannot add an expense to another landlord's property" do
      other = create(:property)
      expect {
        post property_expenses_path(other), params: {
          expense: { date: "2026-07-01", amount: "100", category: "tax" }
        }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET /properties/:property_id/expenses/:id/edit" do
    let(:expense) { create(:expense, property: property) }

    it "returns the edit form inside a turbo frame request" do
      get edit_property_expense_path(property, expense),
          headers: { "Turbo-Frame" => "expense_edit_frame" }
      expect(response).to have_http_status(:ok)
    end

    it "redirects to the property when not a turbo frame request" do
      get edit_property_expense_path(property, expense)
      expect(response).to redirect_to(property_path(property))
    end
  end

  describe "PATCH /properties/:property_id/expenses/:id" do
    let(:expense) { create(:expense, property: property) }

    it "updates the expense and redirects to the property" do
      patch property_expense_path(property, expense), params: {
        expense: { amount: "999.00" }
      }
      expect(response).to redirect_to(property_path(property))
      expect(expense.reload.amount).to eq(999.00)
    end

    it "renders edit with errors on invalid data" do
      patch property_expense_path(property, expense), params: {
        expense: { amount: "-5" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "cannot update another landlord's expense" do
      other_expense = create(:expense)
      expect {
        patch property_expense_path(other_expense.property, other_expense), params: {
          expense: { amount: "100" }
        }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE /properties/:property_id/expenses/:id" do
    let(:expense) { create(:expense, property: property) }

    it "destroys the expense and redirects to the property" do
      delete property_expense_path(property, expense)
      expect(response).to redirect_to(property_path(property))
      expect(property.expenses.reload).not_to include(expense)
    end

    it "cannot delete another landlord's expense" do
      other_expense = create(:expense)
      expect {
        delete property_expense_path(other_expense.property, other_expense)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
