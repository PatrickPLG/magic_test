# 1.2 (§5): a plan built in the wizard is saved as a template from the review
# step; `bin/magic new --template provider-discounts "…"` then opens the wizard
# on the review step, preflights and records straight away.
MagicTest::Testing::WizardFlow.define("ui_template_save_reuse") do
  then_template("provider discounts", "provider renames a discount again")

  ui do
    pick_starter("provider_active_discount")
    describe_test("provider renames a discount (template)")
    new_file(ENV.fetch("MAGIC_TEST_UI_TARGET"))
    next_step
    next_step
    next_step
    save_template("provider discounts")
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
