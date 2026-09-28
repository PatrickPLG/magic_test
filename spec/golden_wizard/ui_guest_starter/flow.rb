# 1.2: the "Guest" starter: no sign-in, the cookie consent cookie, and the
# start page the specs visit most as a guest (terms).
MagicTest::Testing::WizardFlow.define("ui_guest_starter") do
  ui do
    pick_starter("guest")
    describe_test("guest reads the terms")
    new_file(ENV.fetch("MAGIC_TEST_UI_TARGET"))
    next_step
    next_step
    next_step
    raise "preflight failed: #{state[:preflight].inspect}" unless run_preflight[:ok]
    start_recording
  end

  script do |h|
    h.select_text("h1")
    h.press("X", :alt, :shift)
    h.click_on("Tilbage")
    accept_suggestion("have_current_path(root_path)")
    settle
  end
end
