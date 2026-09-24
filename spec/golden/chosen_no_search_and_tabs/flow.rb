MagicTest::Testing::GoldenFlow.define("chosen_no_search_and_tabs") do
  description "provider sets the status with the search-less Chosen select and uses the description"
  setup <<~RUBY
    let!(:provider) { create(:provider) }
    let!(:discount) { create(:discount, provider: provider, name_da: 'Kaffe 20%', status: 'draft') }

    before do
      sign_in_as_provider(provider)
    end
  RUBY
  start "visit(edit_provider_admin_discount_path(provider, discount))"

  script do |h|
    h.click("#discount_status_chosen")
    h.click("#discount_status_chosen .chosen-results li.active-result", text: "Inaktiv")
    h.click("#discount_description").type("Gælder ikke i weekenden.")
    h.click("#discount_name_en").type("Coffee 20%")
    h.click_on("Gem")
    wait_for_suggestion("Rabatten er gemt")
    accept_suggestion("Rabatten er gemt")
    accept_suggestion("discount.reload.status")
    settle
  end
end
