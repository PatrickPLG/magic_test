# Loaded by MagicTest::ScriptedSession inside the recording subprocess
# (MAGIC_TEST_SCRIPT points here). Evaluated with `instance_eval` on the
# scripted-session DSL, so `human`, `command`, `wait_for_steps`,
# `accept_suggestion`, `answer_dialog` and `page` are available.
require "magic_test/testing/golden_flow"

load ENV.fetch("MAGIC_TEST_GOLDEN_FLOW")
flow = MagicTest::Testing::GoldenFlow.registry.fetch(ENV.fetch("MAGIC_TEST_GOLDEN_NAME"))
instance_exec(human, &flow.script_block)
