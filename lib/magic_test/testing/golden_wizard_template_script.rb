# The `--template` fast path of a golden UI flow: the wizard opens on step 4
# with the template's plan; preflight, then start.
require "magic_test/testing/wizard_ui"

extend MagicTest::Testing::WizardUi # rubocop:disable Style/MixinUsage

begin
  wait_until(timeout: 20) { current_step == 4 }
  result = run_preflight
  raise "template preflight failed: #{result.inspect}" unless result[:ok]
  start_recording
rescue Exception => e # rubocop:disable Lint/RescueException
  warn "magic_test wizard template script failed: #{e.class}: #{e.message}\n#{Array(e.backtrace).first(6).join("\n")}"
  session.enqueue("cancel", {})
end
