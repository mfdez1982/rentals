require "rails_helper"

RSpec.describe "Locales", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "POST /set_locale" do
    it "switches the UI language for subsequent requests" do
      post set_locale_path, params: { locale: "es" }
      expect(response).to have_http_status(:redirect)

      get properties_path
      expect(response.body).to include(I18n.t("properties.add_property", locale: :es))
    end

    # The guard checks I18n.available_locales, which includes locales shipped
    # by gems (e.g. Devise's :fr) — those are accepted and render with
    # "translation missing" placeholders. Owner decision (2026-07-13): crafted
    # POSTs getting an ugly result is acceptable; only locales completely
    # unknown to I18n must be ignored.
    it "ignores locales unknown to I18n" do
      post set_locale_path, params: { locale: "xx" }

      get properties_path
      expect(response.body).to include(I18n.t("properties.add_property", locale: :en))
    end
  end
end
