MagicTest::Testing::GoldenFlow.define("cookie_modal_admin") do
  description "provider without the cookie setting accepts only necessary cookies"
  setup <<~RUBY
    let!(:provider) { create(:provider) }

    before do
      provider.user.ensure_authentication_token
      sign_in(provider.user)
      page.driver.set_cookie('auth_token', provider.user.authentication_token)
    end
  RUBY
  start "visit(provider_admin_discounts_path(provider))"

  script do |h|
    page.find("#cookie-modal.show")
    h.click_on("Kun nødvendige")
    page.has_no_css?("#cookie-modal.show")
    h.click_on("Opret rabat")
    h.click("#discount_name_da").type("Te 10%")
    h.click_on("Opret rabat")
    wait_for_suggestion("Rabat oprettet")
    accept_suggestion("Rabat oprettet")
    settle
  end
end
