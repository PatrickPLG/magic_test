MagicTest::Testing::GoldenFlow.define("institution_creates_event") do
  description "institution creates an event"
  setup <<~RUBY
    let!(:institution) { create(:institution, :with_user, :with_specialities, allow_events: true) }
    let!(:category) { create(:category, name: 'Fest') }
    let!(:other_categories) { %w[Foredrag Sport Kultur Musik].map { |n| create(:category, name: n) } }

    before do
      sign_in_as_institution(institution)
    end
  RUBY
  start "visit(institution_students_path(institution))"

  script do |h|
    h.click_on("Arrangementer")
    h.click_on("Opret arrangement")
    h.click("#events_event_name").type("Fredagsbar i Studiz' gård")
    h.click("trix-editor").type("Kom til fredagsbar")
    h.click("#events_event_category_id_chosen")
    h.type("Fe")
    h.click("#events_event_category_id_chosen .chosen-results li.active-result", text: "Fest")
    h.click("#events_event_starts_at").type("24/09-2026 14:00").press(:tab)
    h.click("label", text: "Jeg accepterer Studiz' vilkår")
    h.click_on("Arrangør")
    h.click("#events_event_account_number").type("1234567890")
    h.click_on("Gem arrangement")
    wait_for_suggestion("Arrangement oprettet")
    accept_suggestion("Arrangement oprettet")
    accept_suggestion("Events::Event.count")
    settle
  end
end
