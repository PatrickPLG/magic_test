MagicTest::Testing::GoldenFlow.define("flatpickr_birthday") do
  description "student types a birthday into the flatpickr field with the custom year select"
  setup <<~RUBY
    let!(:student) { create(:student, automatic_verified: true) }

    before do
      student.user.update!(onboarded: true)
      sign_in_as_student(student)
    end
  RUBY
  start "visit(edit_profile_path)"

  script do |h|
    h.click("#student_birthday").type("14/02-2001").press(:tab)
    h.click_on("Gem profil")
    wait_for_suggestion("Profil gemt")
    accept_suggestion("Profil gemt")
    accept_suggestion("student.reload.birthday")
    settle
  end
end
