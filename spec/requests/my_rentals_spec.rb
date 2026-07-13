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
  end
end
