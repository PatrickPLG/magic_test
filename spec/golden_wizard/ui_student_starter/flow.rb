# 1.2: the "Verified student" starter (traits learned from the specs:
# :verified, :onboarded; start page edit_profile) through the four steps.
MagicTest::Testing::WizardFlow.define("ui_student_starter") do
  ui do
    pick_starter("student_verified")
    describe_test("student changes the first name from the starter")
    new_file(ENV.fetch("MAGIC_TEST_UI_TARGET"))
    next_step
    next_step
    next_step
    raise "preflight failed: #{state[:preflight].inspect}" unless run_preflight[:ok]
    start_recording
  end

  script do |h|
    h.click("#student_first_name").select_all.type("Frederikke")
    h.click_on("Gem")
    wait_for_suggestion("student.reload.first_name")
    accept_suggestion("student.reload.first_name")
    settle
  end
end
