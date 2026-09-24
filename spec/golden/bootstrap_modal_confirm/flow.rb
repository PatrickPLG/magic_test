MagicTest::Testing::GoldenFlow.define("bootstrap_modal_confirm") do
  description "provider archives a discount through the ajax-modal confirmation"
  setup <<~RUBY
    let!(:provider) { create(:provider) }
    let!(:discount) { create(:discount, provider: provider, name_da: 'Kaffe 20%') }

    before do
      sign_in_as_provider(provider)
    end
  RUBY
  start "visit(provider_admin_discounts_path(provider))"

  script do |h|
    h.click_on("Arkivér")
    page.find("#ajax-modal.show .modal-title", text: "Arkivér rabat")
    h.click("#ajax-modal button", text: "Ja, arkivér")
    wait_for_suggestion("Rabat arkiveret")
    accept_suggestion("Rabat arkiveret")
    settle
  end
end
