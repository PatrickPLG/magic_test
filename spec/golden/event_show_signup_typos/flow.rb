MagicTest::Testing::GoldenFlow.define("event_show_signup_typos") do
  description "student signs up for an event through buttons with deliberate typos in the copy"
  setup <<~RUBY
    let!(:institution) { create(:institution, :with_user, allow_events: true) }
    let!(:event) { create(:event, institution: institution, name: 'Fredagsbar') }
    let!(:student) { create(:student, automatic_verified: true) }

    before do
      student.user.update!(onboarded: true)
      sign_in_as_student(student)
    end
  RUBY
  start "visit(event_path(event))"

  script do |h|
    h.click_on("Tilmeld dig")
    h.click_on("Forsæt til betaling")
    accept_suggestion("have_current_path(event_path(event")
    h.select_text(".event-description")
    h.press("X", :alt, :shift)
    settle
  end
end
