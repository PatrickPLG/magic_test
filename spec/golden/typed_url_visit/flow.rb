MagicTest::Testing::GoldenFlow.define("typed_url_visit") do
  description "student types a URL, reads the terms and asserts the heading"
  setup <<~RUBY
    let!(:student) { create(:student, automatic_verified: true) }

    before do
      sign_in_as_student(student)
      student.user.update!(onboarded: true)
    end
  RUBY
  start "visit(root_path)"

  script do |h|
    h.visit("/vilkaar")
    h.select_text("h1")
    h.press("X", :alt, :shift)
    h.click_on("Tilbage")
    accept_suggestion("have_current_path(root_path)")
    settle
  end
end
