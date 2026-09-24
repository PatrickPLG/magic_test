MagicTest::Testing::GoldenFlow.define("paste_into_field") do
  description "student pastes into a profile field and saves"
  setup <<~RUBY
    let!(:student) { create(:student, automatic_verified: true, first_name: 'Mette', last_name: 'Frederiksen') }

    before do
      student.user.update!(onboarded: true)
      sign_in_as_student(student)
    end
  RUBY
  start "visit(edit_profile_path)"

  script do |h|
    h.click("#student_last_name").select_all.paste("Nielsen-Holm")
    h.click("#student_bio").paste("Jeg læser jura på 3. semester.\nElsker kaffe.")
    h.click_on("Gem profil")
    wait_for_suggestion("Profil gemt")
    accept_suggestion("Profil gemt")
    accept_suggestion("student.reload.last_name")
    settle
  end
end
