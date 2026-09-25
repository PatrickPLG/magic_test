# After the wizard hands over: the recording window with the toolbar, one screenshot.
dir = ENV.fetch("MAGIC_TEST_SCREENSHOT_DIR")
settle(1.0)
page.save_screenshot(File.join(dir, "wizard-recording.png"))
