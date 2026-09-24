# Scripted human for `rake docs:screenshots`: edits a discount in the fixture
# app with the toolbar mounted and saves a screenshot at each stage.
h = human
dir = ENV.fetch("MAGIC_TEST_SCREENSHOT_DIR")
shot = ->(name) {
  settle(0.8)
  page.save_screenshot(File.join(dir, name))
}
# Scrolls the panel body to its end so the suggestions box is in view.
scroll_panel = -> {
  page.execute_script("var h = document.querySelector('[data-magic-test=toolbar]'); var b = h && h.shadowRoot.querySelector('.body'); if (b) b.scrollTop = b.scrollHeight;")
}

h.click("#discount_name_da").select_all.type("Kaffe 25%")
h.click("#discount_status_chosen")
h.click("#discount_status_chosen .chosen-results li.active-result", text: "Aktiv")
h.click("#discount_category_ids_chosen .chosen-choices")
h.click("#discount_category_ids_chosen .chosen-results li.active-result", text: "Fest")
wait_for_steps(3)
shot.call("toolbar.png")

command("replay_pending")
shot.call("replay.png")

h.click_on("Gem")
wait_for_suggestion("Rabatten er gemt")
scroll_panel.call
shot.call("suggestions.png")
accept_suggestion("Rabatten er gemt")
accept_suggestion("discount.reload.name_da")

set_mode(:assert)
h.click("h5.card-title", text: "Kaffe 25%")
wait_for_steps(7)
scroll_panel.call
shot.call("assert-mode.png")
