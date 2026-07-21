require "rails_helper"

RSpec.describe "Recollections", type: :request do
  let(:user) { create(:user) }
  let(:landlord) { user.landlord }
  let(:property) { create(:property, landlord: landlord) }
  let(:agreement) do
    create(:rental_agreement, property: property,
           start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31))
  end
  let(:expense) { create(:expense, :collectable, property: property) }

  before { sign_in user }

  describe "GET /properties/:pid/expenses/:eid/recollections/new" do
    it "renders the preview form when the expense is collectable and an agreement overlaps" do
      tenant = create(:agreement_tenant, :accepted, rental_agreement: agreement)
      get new_property_expense_recollection_path(property, expense)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(tenant.invited_email)
    end

    it "redirects with an alert when the expense is not collectable" do
      plain_expense = create(:expense, property: property)
      get new_property_expense_recollection_path(property, plain_expense)
      expect(response).to redirect_to(property_path(property))
      expect(flash[:alert]).to be_present
    end

    it "shows the no-overlap explanation when no agreement covers the period" do
      create(:rental_agreement, property: property, start_date: Date.new(2020, 1, 1), end_date: Date.new(2020, 12, 31))
      get new_property_expense_recollection_path(property, expense)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("recollections.no_overlapping_agreements_explanation"))
    end

    it "cannot be reached for another landlord's property" do
      other_expense = create(:expense, :collectable)
      expect {
        get new_property_expense_recollection_path(other_expense.property, other_expense)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST /properties/:pid/expenses/:eid/recollections" do
    let!(:tenant1) { create(:agreement_tenant, :accepted, rental_agreement: agreement) }
    let!(:tenant2) { create(:agreement_tenant, :accepted, rental_agreement: agreement) }

    def slices_params(shares)
      {
        slices: {
          "0" => {
            rental_agreement_id: agreement.id,
            due_date: "2025-07-15",
            shares: shares
          }
        }
      }
    end

    it "creates recollections and redirects with a success notice" do
      post property_expense_recollections_path(property, expense), params: slices_params(
        "0" => { agreement_tenant_id: tenant1.id, include: "1", amount: "125.00" },
        "1" => { agreement_tenant_id: tenant2.id, include: "1", amount: "125.00" }
      )
      expect(response).to redirect_to(property_path(property))
      expect(expense.recollections.count).to eq(2)
      expect(flash[:notice]).to eq(I18n.t("recollections.created", count: 2))
    end

    it "excludes an unchecked tenant's share" do
      post property_expense_recollections_path(property, expense), params: slices_params(
        "0" => { agreement_tenant_id: tenant1.id, include: "1", amount: "125.00" },
        "1" => { agreement_tenant_id: tenant2.id, include: "0", amount: "125.00" }
      )
      expect(expense.recollections.count).to eq(1)
      expect(expense.recollections.first.agreement_tenant).to eq(tenant1)
    end

    it "creates a single no-payer recollection when every tenant is unchecked" do
      post property_expense_recollections_path(property, expense), params: slices_params(
        "0" => { agreement_tenant_id: tenant1.id, include: "0", amount: "125.00" },
        "1" => { agreement_tenant_id: tenant2.id, include: "0", amount: "125.00" }
      )
      expect(expense.recollections.count).to eq(1)
      recollection = expense.recollections.first
      expect(recollection.agreement_tenant).to be_nil
    end

    it "does not create duplicate rows and shows an alert when re-submitted for the same agreement" do
      post property_expense_recollections_path(property, expense), params: slices_params(
        "0" => { agreement_tenant_id: tenant1.id, include: "1", amount: "125.00" },
        "1" => { agreement_tenant_id: tenant2.id, include: "1", amount: "125.00" }
      )
      expect(expense.recollections.count).to eq(2)

      post property_expense_recollections_path(property, expense), params: slices_params(
        "0" => { agreement_tenant_id: tenant1.id, include: "1", amount: "125.00" },
        "1" => { agreement_tenant_id: tenant2.id, include: "1", amount: "125.00" }
      )
      expect(response).to redirect_to(property_path(property))
      expect(flash[:alert]).to eq(I18n.t("recollections.nothing_to_generate"))
      expect(expense.recollections.count).to eq(2)
    end

    it "redirects with an alert when the expense is not collectable" do
      plain_expense = create(:expense, property: property)
      post property_expense_recollections_path(property, plain_expense), params: { slices: {} }
      expect(response).to redirect_to(property_path(property))
      expect(flash[:alert]).to eq(I18n.t("recollections.not_collectable"))
    end

    it "cannot create recollections on another landlord's property" do
      other_expense = create(:expense, :collectable)
      expect {
        post property_expense_recollections_path(other_expense.property, other_expense), params: { slices: {} }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "PATCH /properties/:pid/recollections/:id/mark_paid" do
    let(:recollection) { create(:recollection, rental_agreement: agreement, expense: expense, property: property) }

    it "marks the recollection paid and redirects with a notice" do
      patch mark_paid_property_recollection_path(property, recollection)
      expect(response).to redirect_to(property_path(property))
      expect(recollection.reload).to be_paid
      expect(recollection.paid_date).to eq(Date.today)
    end

    it "cannot mark paid another landlord's recollection" do
      other_recollection = create(:recollection)
      expect {
        patch mark_paid_property_recollection_path(other_recollection.property, other_recollection)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "PATCH /properties/:pid/recollections/:id/mark_unpaid" do
    let(:recollection) do
      create(:recollection, rental_agreement: agreement, expense: expense, property: property,
             status: :paid, paid_date: Date.today)
    end

    it "reverts the recollection to pending and clears the paid date" do
      patch mark_unpaid_property_recollection_path(property, recollection)
      expect(response).to redirect_to(property_path(property))
      expect(recollection.reload).to be_pending
      expect(recollection.paid_date).to be_nil
    end

    it "renders the unmark button on a paid row and the mark-paid button on a pending one" do
      recollection
      # A second expense: (expense, agreement) is unique-indexed, so the pending
      # row can't reuse the paid row's expense.
      pending_one = create(:recollection, rental_agreement: agreement, property: property,
                           expense: create(:expense, :collectable, property: property))

      get property_path(property)

      expect(response.body).to include(mark_unpaid_property_recollection_path(property, recollection))
      expect(response.body).to include(mark_paid_property_recollection_path(property, pending_one))
      expect(response.body).not_to include(mark_paid_property_recollection_path(property, recollection))
    end

    it "cannot mark unpaid another landlord's recollection" do
      other_recollection = create(:recollection, status: :paid, paid_date: Date.today)
      expect {
        patch mark_unpaid_property_recollection_path(other_recollection.property, other_recollection)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE /properties/:pid/recollections/:id" do
    let!(:recollection) { create(:recollection, rental_agreement: agreement, expense: expense, property: property) }

    it "destroys the recollection and redirects with a notice" do
      expect {
        delete property_recollection_path(property, recollection)
      }.to change(Recollection, :count).by(-1)
      expect(response).to redirect_to(property_path(property))
    end

    it "cannot delete another landlord's recollection" do
      other_recollection = create(:recollection)
      expect {
        delete property_recollection_path(other_recollection.property, other_recollection)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
