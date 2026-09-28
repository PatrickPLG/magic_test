# 1.2: the "Admin in the backoffice" starter plus one lead added in step 2 with
# an attribute override; the recorder edits the lead's status.
MagicTest::Testing::WizardFlow.define("ui_admin_starter") do
  ui do
    pick_starter("admin_backoffice")
    describe_test("admin marks a lead as contacted")
    new_file(ENV.fetch("MAGIC_TEST_UI_TARGET"))
    next_step
    add_record("lead")
    set_trait("w-model-1", "contacted", on: false) # the specs' default is :contacted; this test changes a new lead to contacted
    set_attribute(1, "name", "Lead A")
    next_step
    next_step
    raise "preflight failed: #{state[:preflight].inspect}" unless run_preflight[:ok]
    start_recording
  end

  script do |h|
    h.click_on("Rediger")
    h.native_select("Status", "contacted")
    h.click_on("Gem")
    wait_for_suggestion("lead.reload.status")
    accept_suggestion("lead.reload.status")
    settle
  end
end
