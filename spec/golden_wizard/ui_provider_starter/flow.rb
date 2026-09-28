# 1.2: through the four steps of the browser wizard: the "Provider with an
# active discount" starter, a description, a new file, preflight, record.
MagicTest::Testing::WizardFlow.define("ui_provider_starter") do
  ui do
    pick_starter("provider_active_discount")
    describe_test("provider renames a discount from the starter")
    new_file(ENV.fetch("MAGIC_TEST_UI_TARGET"))
    next_step
    next_step
    next_step
    raise "preflight failed: #{state[:preflight].inspect}" unless run_preflight[:ok]
    start_recording
  end

  script do |h|
    h.click_on("Rediger")
    h.click("#discount_name_da").select_all.type("Kaffe 25%")
    h.click_on("Gem")
    wait_for_suggestion("Rabatten er gemt")
    accept_suggestion("Rabatten er gemt")
    accept_suggestion("discount.reload.name_da")
    settle
  end
end
