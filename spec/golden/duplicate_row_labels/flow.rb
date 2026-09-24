MagicTest::Testing::GoldenFlow.define("duplicate_row_labels") do
  description "backoffice edits the second lead in a table where every row says Rediger"
  setup <<~RUBY
    let!(:provider) { create(:provider) }
    let!(:leads) { %w[Anders Bente Carl].map { |n| create(:lead, name: n, email: "\#{n.downcase}@x.dk") } }

    before do
      sign_in_as_provider(provider)
    end
  RUBY
  start "visit(backoffice_leads_path)"

  script do |h|
    h.click("#lead_#{Lead.find_by!(name: "Bente").id} a", text: "Rediger")
    h.click("#lead_status").press(:down)
    h.click("#lead_note").type("Ringet op")
    h.click_on("Gem lead")
    wait_for_suggestion("Lead opdateret")
    accept_suggestion("Lead opdateret")
    settle
  end
end
