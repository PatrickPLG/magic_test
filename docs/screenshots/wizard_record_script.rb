# After the wizard hands over: the recording window with the toolbar and one
# step, then the wizard window's status screen (1.2, B9); one screenshot each.
dir = ENV.fetch("MAGIC_TEST_SCREENSHOT_DIR")
h = human
recording_window = page.current_window
settle(1.0)
h.click_on("Rediger")
settle(1.0)
page.save_screenshot(File.join(dir, "wizard-recording-window.png"))
wizard_window = (page.windows - [recording_window]).first
if wizard_window
  page.within_window(wizard_window) do
    deadline = Time.now + 10
    sleep 0.2 until page.evaluate_script("(document.getElementById('recording-count') || {}).textContent || ''").start_with?("1 step") || Time.now > deadline
    page.save_screenshot(File.join(dir, "wizard-recording.png"))
  end
  page.switch_to_window(recording_window)
end
settle
