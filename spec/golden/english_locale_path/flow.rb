MagicTest::Testing::GoldenFlow.define("english_locale_path") do
  description "institution uses the English locale path"
  setup <<~RUBY
    let!(:institution) { create(:institution, :with_user, allow_events: true) }

    before do
      sign_in_as_institution(institution)
    end
  RUBY
  start "visit(institution_students_path(institution))"

  script do |h|
    h.visit("/en/institutions/#{Institution.first.id}/events")
    h.click_on("Create event")
    h.click("#events_event_name").type("English event")
    h.click_on("Save event")
    wait_for_suggestion("Event created")
    accept_suggestion("Event created")
    accept_suggestion("have_current_path(institution_events_en_path(institution))")
    settle
  end
end
