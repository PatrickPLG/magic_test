# Loaded by BrowserSession::ScriptDSL inside the wizard subprocess of a golden
# UI flow (MAGIC_TEST_WIZARD_SCRIPT points here): drives the four steps.
require "magic_test/testing/wizard_flow"
require "magic_test/testing/wizard_ui"

extend MagicTest::Testing::WizardUi # rubocop:disable Style/MixinUsage

load ENV.fetch("MAGIC_TEST_GOLDEN_FLOW")
flow = MagicTest::Testing::WizardFlow.registry.fetch(ENV.fetch("MAGIC_TEST_GOLDEN_NAME"))
begin
  instance_exec(&flow.ui_block)
rescue Exception => e # rubocop:disable Lint/RescueException
  warn "magic_test wizard ui script failed: #{e.class}: #{e.message}\n#{Array(e.backtrace).first(6).join("\n")}"
  session.enqueue("cancel", {})
end
