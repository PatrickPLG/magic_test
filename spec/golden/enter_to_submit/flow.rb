MagicTest::Testing::GoldenFlow.define("enter_to_submit") do
  description "student sends a message by pressing Enter"
  setup <<~RUBY
    let!(:student) { create(:student, automatic_verified: true) }

    before do
      student.user.update!(onboarded: true)
      sign_in_as_student(student)
    end
  RUBY
  start "visit(user_messages_path)"

  script do |h|
    h.click("#user_message_body").type("Hej, kan I hjælpe mig?").press(:enter)
    wait_for_suggestion("Besked sendt")
    accept_suggestion("Besked sendt")
    accept_suggestion("UserMessage.count")
    settle
  end
end
