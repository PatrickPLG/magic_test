MagicTest::Testing::GoldenFlow.define("kaminari_pagination") do
  description "backoffice pages to the second page of leads and edits one"
  setup <<~RUBY
    let!(:provider) { create(:provider) }
    let!(:leads) { %w[Anders Bente Carl Dorte Erik].map { |n| create(:lead, name: n, email: "\#{n.downcase}@x.dk") } }

    before do
      sign_in_as_provider(provider)
    end
  RUBY
  start "visit(backoffice_leads_path)"

  script do |h|
    h.click("nav.pagination a", text: "2")
    page.find("#leads-table", text: "Dorte")
    h.click("#lead_#{Lead.find_by!(name: "Erik").id} a", text: "Rediger")
    h.click("#lead_name").select_all.type("Erik Hansen")
    h.click_on("Gem lead")
    wait_for_suggestion("Lead opdateret")
    accept_suggestion("Lead opdateret")
    settle
  end
end
