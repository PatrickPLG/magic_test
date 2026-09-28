# 1.2: the "Institution leader" starter (traits learned: :with_user,
# :with_specialities), the :allow_events trait ticked, a category record with
# an override, the events page the specs visit most; the recorder creates an event.
MagicTest::Testing::WizardFlow.define("ui_institution_starter") do
  ui do
    pick_starter("institution_leader")
    describe_test("institution leader creates an event from the starter")
    new_file(ENV.fetch("MAGIC_TEST_UI_TARGET"))
    next_step
    set_trait("w-role", "allow_events")
    add_record("category")
    set_attribute(1, "name", "Fest")
    next_step
    next_step
    raise "preflight failed: #{state[:preflight].inspect}" unless run_preflight[:ok]
    start_recording
  end

  script do |h|
    h.click_on("Opret arrangement")
    h.click("#events_event_name").type("Fredagsbar")
    h.click("trix-editor").type("Kom til fredagsbar")
    h.click("#events_event_category_id_chosen")
    h.type("Fe")
    h.click("#events_event_category_id_chosen .chosen-results li.active-result", text: "Fest")
    h.click("#events_event_starts_at").type("24/09-2026 14:00").press(:tab)
    page.has_no_css?(".flatpickr-calendar.open") # the calendar can cover the terms label at other window sizes (the Studiz mirror runs at Rails' 1400×1400)
    h.click("label", text: "Jeg accepterer Studiz' vilkår")
    raise "the terms checkbox did not toggle" unless page.find("#events_event_terms_accepted", visible: :all).checked?
    h.click_on("Arrangør")
    h.click("#events_event_account_number").type("1234567890")
    h.click_on("Gem arrangement")
    wait_for_suggestion("Arrangement oprettet")
    accept_suggestion("Arrangement oprettet")
    accept_suggestion("Events::Event.count")
    settle
  end
end
