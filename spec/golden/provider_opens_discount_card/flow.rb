# B7 (1.2): the discount card and the link inside its modal carry factory
# data (a random name), so the generated locators must refer to the lets:
# find("#discount-card-#{discount.id}"), click_on(discount.name_da). A literal
# name or id would fail the replays (the name differs in every process).
MagicTest::Testing::GoldenFlow.define("provider_opens_discount_card") do
  description "provider opens a discount card and renames it"
  setup <<~RUBY
    let!(:provider) { create(:provider, :with_cvr) }
    let!(:other_discount) { create(:discount, provider: provider, name_da: "Rabat \#{SecureRandom.hex(3)}") }
    let!(:discount) { create(:discount, provider: provider, name_da: "Rabat \#{SecureRandom.hex(3)}") }

    before do
      sign_in_as_provider(provider)
    end
  RUBY
  start "visit(provider_admin_discounts_path(provider))"

  script do |h|
    target = Discount.order(:id).last
    h.click(page.find(".deal", text: target.name_da))
    h.click("#full-view-modal .discount-name-link")
    h.click("#discount_name_da").select_all.type("Kaffe 25%")
    h.click_on("Gem")
    wait_for_suggestion("Rabatten er gemt")
    accept_suggestion("Rabatten er gemt")
    accept_suggestion("discount.reload.name_da")
    settle
  end
end
