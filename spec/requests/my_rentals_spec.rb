require "rails_helper"

RSpec.describe "MyRentals", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /my_rentals" do
    it "lists agreements the user is an accepted tenant of, including expired ones" do
      agreement = create(:rental_agreement,
        start_date: 2.years.ago.to_date, end_date: 1.year.ago.to_date)
      create(:agreement_tenant, :accepted, rental_agreement: agreement, user: user, invited_email: user.email)

      get my_rentals_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(agreement.property.name)
    end

    it "does not list an agreement the user is only pending on" do
      agreement = create(:rental_agreement)
      create(:agreement_tenant, rental_agreement: agreement, user: user, invited_email: user.email, status: :pending)

      get my_rentals_path

      expect(response.body).not_to include(my_rental_path(agreement))
    end

    it "does not list an agreement the user is rejected on" do
      agreement = create(:rental_agreement)
      create(:agreement_tenant, :rejected, rental_agreement: agreement, user: user, invited_email: user.email)

      get my_rentals_path

      expect(response.body).not_to include(my_rental_path(agreement))
    end

    it "does not list an agreement the user was removed from" do
      agreement = create(:rental_agreement)
      create(:agreement_tenant, :removed, rental_agreement: agreement, user: user, invited_email: user.email)

      get my_rentals_path

      expect(response.body).not_to include(my_rental_path(agreement))
    end

    it "does not list an agreement the user has no relation to" do
      agreement = create(:rental_agreement)

      get my_rentals_path

      expect(response.body).not_to include(my_rental_path(agreement))
    end

    it "shows a pending recollections count badge for an agreement with pending charges" do
      agreement = create(:rental_agreement)
      agreement_tenant = create(:agreement_tenant, :accepted, rental_agreement: agreement, user: user, invited_email: user.email)
      create(:recollection, rental_agreement: agreement, agreement_tenant: agreement_tenant, property: agreement.property)
      create(:recollection, rental_agreement: agreement, agreement_tenant: agreement_tenant, property: agreement.property)

      get my_rentals_path

      expect(response.body).to include(I18n.t("my_rentals.recollections.pending_badge", count: 2))
    end
  end

  describe "GET /my_rentals/:id" do
    it "renders an accepted agreement with its payments" do
      agreement = create(:rental_agreement)
      create(:agreement_tenant, :accepted, rental_agreement: agreement, user: user, invited_email: user.email)
      payment = create(:payment, rental_agreement: agreement, amount: 123.45)

      get my_rental_path(agreement)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ActiveSupport::NumberHelper.number_to_currency(payment.amount))
    end

    it "raises RecordNotFound for an agreement the user is not an accepted tenant of" do
      agreement = create(:rental_agreement)

      expect {
        get my_rental_path(agreement)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "renders the user's own recollection with its amount" do
      agreement = create(:rental_agreement)
      agreement_tenant = create(:agreement_tenant, :accepted, rental_agreement: agreement, user: user, invited_email: user.email)
      recollection = create(:recollection, rental_agreement: agreement, agreement_tenant: agreement_tenant, amount: 77.50, property: agreement.property)

      get my_rental_path(agreement)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ActiveSupport::NumberHelper.number_to_currency(recollection.amount))
    end

    it "does not render another tenant's recollection on the same agreement" do
      agreement = create(:rental_agreement)
      create(:agreement_tenant, :accepted, rental_agreement: agreement, user: user, invited_email: user.email)

      other_tenant = create(:user)
      other_agreement_tenant = create(:agreement_tenant, :accepted, rental_agreement: agreement, user: other_tenant, invited_email: other_tenant.email)
      other_recollection = create(:recollection, rental_agreement: agreement, agreement_tenant: other_agreement_tenant, amount: 99.99, property: agreement.property)

      get my_rental_path(agreement)

      expect(response.body).not_to include(ActiveSupport::NumberHelper.number_to_currency(other_recollection.amount))
    end

    it "does not render a recollection with no payer" do
      agreement = create(:rental_agreement)
      create(:agreement_tenant, :accepted, rental_agreement: agreement, user: user, invited_email: user.email)
      unassigned_recollection = create(:recollection, rental_agreement: agreement, agreement_tenant: nil, amount: 55.55, property: agreement.property)

      get my_rental_path(agreement)

      expect(response.body).not_to include(ActiveSupport::NumberHelper.number_to_currency(unassigned_recollection.amount))
    end
  end
end
