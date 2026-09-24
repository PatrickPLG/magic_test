MagicTest::Testing::GoldenFlow.define("alert_from_js_erb") do
  description "provider sends a reminder and the js.erb response alerts"
  setup <<~RUBY
    let!(:provider) { create(:provider) }
    let!(:discount) { create(:discount, provider: provider, name_da: 'Kaffe 20%') }

    before do
      sign_in_as_provider(provider)
    end
  RUBY
  start "visit(provider_admin_discounts_path(provider))"

  script do |h|
    h.click_on("Send påmindelse")
    answer_dialog(:accept)
    set_mode(:assert, assertion_type: "css")
    h.click(".js-reminder-count")
    settle
  end
end
