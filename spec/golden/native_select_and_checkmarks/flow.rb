MagicTest::Testing::GoldenFlow.define("native_select_and_checkmarks") do
  description "student picks a country, a gender and the newsletter with custom checkmarks"
  setup <<~RUBY
    let!(:student) { create(:student, automatic_verified: true) }

    before do
      student.user.update!(onboarded: true)
      sign_in_as_student(student)
    end
  RUBY
  start "visit(edit_profile_path)"

  script do |h|
    h.native_select("Land", "Sverige")
    h.click("label.checkmark-container", text: "Kvinde")
    h.click("label.checkmark-container", text: "nyhedsbrev")
    h.click_on("Gem profil")
    wait_for_suggestion("Profil gemt")
    accept_suggestion("Profil gemt")
    accept_suggestion("student.reload.country")
    settle
  end
end
