# B8 (1.2): "Arkiver nu" is a rails-ujs remote GET link whose archive_now.js.erb
# removes the card and shows a toast; the UPDATE it runs must still produce
# the reload suggestion (on SQLite and on Postgres), and the toast its own.
MagicTest::Testing::GoldenFlow.define("provider_archives_discount_now") do
  description "provider archives a discount from its card"
  setup <<~RUBY
    let!(:provider) { create(:provider, :with_cvr) }
    let!(:discount) { create(:discount, provider: provider, name_da: 'Kaffe 20%') }
    let!(:other_discount) { create(:discount, provider: provider, name_da: 'Te 10%') }

    before do
      sign_in_as_provider(provider)
    end
  RUBY
  start "visit(provider_admin_discounts_path(provider))"

  script do |h|
    h.click(page.find(".deal", text: "Kaffe 20%"))
    h.click("#full-view-modal .archive-now")
    wait_for_suggestion("discount.reload.archived")
    accept_suggestion("Rabatten er arkiveret")
    accept_suggestion("discount.reload.archived")
    settle
  end
end
