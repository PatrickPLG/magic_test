MagicTest::Testing::GoldenFlow.define("edit_middle_of_value") do
  description "student edits the middle of a typed value before saving"
  setup <<~RUBY
    let!(:student) { create(:student, automatic_verified: true, first_name: 'Mette') }

    before do
      student.user.update!(onboarded: true)
      sign_in_as_student(student)
    end
  RUBY
  start "visit(edit_profile_path)"

  script do |h|
    h.fill("#student_first_name", "Anne Marie")
    h.press(:home)
    4.times { h.press(:right) }
    h.type("-")
    h.press(:end).press(:backspace).press(:backspace).type("ia")
    h.click_on("Gem profil")
    wait_for_suggestion("Profil gemt")
    accept_suggestion("Profil gemt")
    accept_suggestion("student.reload.first_name")
    settle
  end
end
