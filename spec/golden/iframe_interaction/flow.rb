MagicTest::Testing::GoldenFlow.define("iframe_interaction") do
  description "student searches inside the same-origin preview iframe"
  setup <<~RUBY
    let!(:student) { create(:student, automatic_verified: true) }

    before do
      student.user.update!(onboarded: true)
      sign_in_as_student(student)
    end
  RUBY
  start "visit(preview_path)"

  script do |h|
    page.within_frame("preview") do
      frame_page = page
      frame_page.find("#q")
      MagicTest::Testing::ScriptedHuman.new(frame_page).click("#q").type("kaffe").click_on("Søg")
      frame_page.find("#frame-result")
      MagicTest::Testing::ScriptedHuman.new(frame_page).select_text("#frame-result").press("X", :alt, :shift)
    end
    settle 0.5
  end
end
