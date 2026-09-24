MagicTest::Testing::GoldenFlow.define("provider_edits_discount") do
  description "provider edits a discount"
  setup <<~RUBY
    let!(:provider) { create(:provider) }
    let!(:discount) { create(:discount, provider: provider, name_da: 'Kaffe 20%', status: 'draft') }
    let!(:categories) { %w[Fest Foredrag Sport Kultur Musik].map { |n| create(:category, name: n) } }

    before do
      sign_in_as_provider(provider)
    end
  RUBY
  start "visit(provider_admin_discounts_path(provider))"

  script do |h|
    h.click_on("Rediger")
    h.click("#discount_name_da").select_all.type("Kaffe 25%")
    h.click("#discount_status_chosen")
    h.click("#discount_status_chosen .chosen-results li.active-result", text: "Aktiv")
    h.click("#discount_category_ids_chosen .chosen-choices")
    h.type("Sp")
    h.click("#discount_category_ids_chosen .chosen-results li.active-result", text: "Sport")
    h.click("#discount_category_ids_chosen .chosen-choices")
    h.click("#discount_category_ids_chosen .chosen-results li.active-result", text: "Fest")
    h.click(page.find("#discount_category_ids_chosen li.search-choice", text: "Sport").find("a.search-choice-close"))
    h.attach("input.cover-image-upload", File.expand_path("../../fixtures/files/cover.png", __dir__))
    h.click("#image-cropper-modal .image-cropper-apply")
    h.click_on("Gem")
    wait_for_suggestion("Rabatten er gemt")
    accept_suggestion("Rabatten er gemt")
    accept_suggestion("discount.reload.name_da")
    settle
  end
end
