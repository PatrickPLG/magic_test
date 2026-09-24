MagicTest::Testing::GoldenFlow.define("new_window_link") do
  description "provider opens the invoice in a new window and marks it paid"
  setup <<~RUBY
    let!(:provider) { create(:provider) }
    let!(:invoice) { create(:invoice, provider: provider, number: 'F-2026-1') }

    before do
      sign_in_as_provider(provider)
    end
  RUBY
  start "visit(provider_admin_discounts_path(provider))"

  script do |h|
    h.click_on("Se faktura")
    new_window = page.driver.browser.window_handles.last
    page.driver.browser.switch_to_window(new_window)
    page.find("h1", text: "Faktura")
    other = MagicTest::Testing::ScriptedHuman.new(page)
    other.click("label", text: "Betalt")
    other.click_on("Udskriv")
    settle 0.5
  end
end
