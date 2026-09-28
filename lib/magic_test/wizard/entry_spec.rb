# The example `bin/magic new` runs: a real system example (so the host's
# driver, DatabaseCleaner, FactoryBot and helper configuration apply) that
# hands itself to the wizard. Never loaded by the normal suite (it lives
# outside spec/).
require "rails_helper"
require "magic_test/wizard/runner"

RSpec.describe("magic_test wizard", :js, type: :system) do
  # B1: the host may register no default driver (Studiz sets it per spec).
  before { MagicTest::Wizard.apply_driver!(self) }

  it "creates a new system test" do
    MagicTest::Wizard::Runner.run(self)
  end
end
