MagicTest::Testing::GoldenFlow.define("assert_mode_clicks") do
  description "institution asserts fields, a select, a button and a row count with assert mode"
  setup <<~RUBY
    let!(:institution) { create(:institution, :with_user, allow_events: true) }
    let!(:events) { %w[Fredagsbar Foredrag].map { |n| create(:event, institution: institution, name: n) } }

    before do
      sign_in_as_institution(institution)
    end
  RUBY
  start "visit(institution_events_path(institution))"

  script do |h|
    set_mode(:assert, assertion_type: "count")
    h.click("#events-table tr", match: :first)
    h.click_on("Opret arrangement")
    h.click("#events_event_name").type("Nyt navn")
    set_mode(:assert, assertion_type: "field")
    h.click("#events_event_name")
    set_mode(:assert, assertion_type: "button")
    h.click_on("Gem arrangement")
    set_mode(:assert, assertion_type: "unchecked")
    h.click("#events_event_published")
    h.select_text("h1")
    h.press("X", :alt, :shift)
    settle
  end
end
