require "rails_helper"

RSpec.describe "Expense documents", type: :request do
  let(:user) { create(:user) }
  let(:landlord) { user.landlord }
  let(:property) { create(:property, landlord: landlord) }
  let(:expense) { create(:expense, property: property) }
  let(:pdf) { fixture_file_upload("lease.pdf", "application/pdf") }

  before do
    Flipper.enable_group(:expense_document, :pro_and_up)
    landlord.update!(plan: :pro)
    sign_in user
  end

  after { Flipper.remove(:expense_document) }

  describe "attaching via create/update" do
    it "attaches a PDF when creating an expense" do
      post property_expenses_path(property), params: {
        expense: { date: Date.today, category: "insurance", amount: 120, invoice_document: pdf }
      }

      expect(response).to redirect_to(property_path(property))
      expect(property.expenses.last.invoice_document).to be_attached
    end

    it "attaches a PDF when updating an expense" do
      patch property_expense_path(property, expense), params: {
        expense: { invoice_document: pdf }
      }

      expect(expense.reload.invoice_document).to be_attached
    end

    it "rejects a non-PDF and re-renders with an error" do
      patch property_expense_path(property, expense), params: {
        expense: { invoice_document: fixture_file_upload("not_a_pdf.txt", "text/plain") }
      }

      expect(expense.reload.invoice_document).not_to be_attached
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "removes an attached document when requested" do
      expense.invoice_document.attach(pdf)

      patch property_expense_path(property, expense), params: {
        expense: { description: "Updated", remove_invoice_document: "1" }
      }

      expect(expense.reload.invoice_document).not_to be_attached
    end

    it "is blocked for a free landlord (the file param is dropped)" do
      landlord.update!(plan: :free)

      patch property_expense_path(property, expense), params: {
        expense: { invoice_document: pdf }
      }

      expect(expense.reload.invoice_document).not_to be_attached
    end
  end

  describe "GET document (download)" do
    it "streams the attached document as a PDF attachment" do
      expense.invoice_document.attach(pdf)

      get document_property_expense_path(property, expense)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end

    it "redirects when nothing is attached" do
      get document_property_expense_path(property, expense)
      expect(response).to redirect_to(property_path(property))
    end

    it "still lets a downgraded free landlord download their own document" do
      expense.invoice_document.attach(pdf)
      landlord.update!(plan: :free)

      get document_property_expense_path(property, expense)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
    end

    it "cannot download another landlord's expense document" do
      other_expense = create(:expense)
      other_expense.invoice_document.attach(pdf)

      expect {
        get document_property_expense_path(other_expense.property, other_expense)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
