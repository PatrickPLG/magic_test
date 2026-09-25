# Loaded by MagicTest::ScriptedSession inside the wizard subprocess once the
# recorder has started (MAGIC_TEST_SCRIPT points here).
require "magic_test/testing/wizard_flow"

load ENV.fetch("MAGIC_TEST_GOLDEN_FLOW")
flow = MagicTest::Testing::WizardFlow.registry.fetch(ENV.fetch("MAGIC_TEST_GOLDEN_NAME"))
instance_exec(human, &flow.script_block)
