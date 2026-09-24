MagicTest::Testing::GoldenFlow.define("delete_with_confirm") do
  description "provider deletes a discount after a data-confirm dialog"
  setup <<~RUBY
    let!(:provider) { create(:provider) }
    let!(:discount) { create(:discount, provider: provider, name_da: 'Kaffe 20%') }

    before do
      sign_in_as_provider(provider)
    end
  RUBY
  start "visit(provider_admin_discounts_path(provider))"

  script do |h|
    h.click_on("Slet")
    answer_dialog(:accept)
    wait_for_suggestion("Rabat slettet")
    accept_suggestion("Rabat slettet")
    accept_suggestion("Discount.count")
    settle
  end
end
