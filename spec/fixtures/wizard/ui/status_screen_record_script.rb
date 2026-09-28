# B9 (1.2): the recording half of the status-screen UI spec. The recorder runs
# in the window the preflight opened; the wizard window must still be there,
# showing where the recording is, the file, a live step count and mirrors of
# Save / Save & finish. Runs inside the recorder's scripted session.
h = human
recording_window = page.current_window
raise "the wizard window was closed after Start (#{page.windows.size} window(s) open)" unless page.windows.size == 2
wizard_window = (page.windows - [recording_window]).first
def status_text(page)
  page.evaluate_script("(document.getElementById('recording-status') || {}).textContent || ''")
end

def count_text(page)
  page.evaluate_script("(document.getElementById('recording-count') || {}).textContent || ''")
end

def wait_until(what, timeout: 10)
  deadline = Time.now + timeout
  until yield
    raise "timed out waiting for #{what}; status screen says: #{status_text(page).strip.gsub(/\s+/, " ")[0, 300].inspect}" if Time.now > deadline
    sleep 0.1
  end
end
page.within_window(wizard_window) do
  wait_until("the status screen") { status_text(page).include?("Recording is running in the other window") }
  raise "status screen lacks the file path" unless status_text(page).include?(ENV.fetch("MAGIC_TEST_UI_TARGET"))
  wait_until("the step count") { count_text(page).match?(/\A0 steps\b/) }
  raise "no bring-to-front button" unless page.has_css?("#recording-front")
  raise "no Save / Save & finish mirrors" unless page.has_css?("#recording-save") && page.has_css?("#recording-finish")
end
page.switch_to_window(recording_window)
h.click_on("Rediger")
settle
page.within_window(wizard_window) do
  wait_until("the live step count") { count_text(page).match?(/\A1 step\b/) }
  h.click("#recording-finish")
end
wait_until("the recording to finish", timeout: 15) { %w[finished saved].include?(state["status"]) }
puts "B9 OK: status screen shows the file, the live step count and finishes the recording"
