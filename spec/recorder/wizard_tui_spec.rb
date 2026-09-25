require "rails_helper"
require "magic_test/wizard/runner"
require "magic_test/wizard/tui"
require "stringio"

# The terminal wizard end to end inside a real system example: preflight in
# this Chrome, the skeleton written, recording handed over (stubbed here).
RSpec.describe("Terminal wizard", :recorder, type: :system) do
  let(:root) { Rails.root.join("tmp/wizard_tui") }
  let(:target) { root.join("spec/system/provider/renames_spec.rb") }
  let(:output) { StringIO.new }

  before { FileUtils.rm_rf(root) }

  def run_tui(answers)
    runner = MagicTest::Wizard::Runner.new(self)
    recorded = nil
    allow(runner).to(receive(:record)) { |call_site, _plan| recorded = call_site }
    tui = MagicTest::Wizard::TUI.new(runner, input: StringIO.new(answers.join("\n") + "\n"), output: output)
    tui.run
    [recorded, runner]
  end

  it "asks the questions, preflights in this browser, writes the skeleton and starts recording" do
    answers = [
      "provider renames a discount", "new file", target.to_s,
      "Provider", "provider", "with_cvr",
      "discount", "discount", "active", "1", "provider", "name_da=Kaffe 20%", "", "",
      "provider_admin_discounts_path", "provider", "da",
      "", "", "desktop", "", "", "",
      "y", # run preflight
      "y"  # write and record
    ]
    recorded, = run_tui(answers)
    text = output.string
    expect(text).to(include("preflight passed: 200 /udbydere/"))
    expect(recorded.path).to(eq(target.to_s))
    expect(File.read(target)).to(include("let!(:discount) { create(:discount, :active, provider: provider, name_da: 'Kaffe 20%') }", "magic_sign_in(provider.user)", "visit(provider_admin_discounts_path(provider))\n    magic_test"))
    expect(File.read(target).lines[recorded.line - 1].strip).to(eq("magic_test"))
    expect(page.current_path).to(match(%r{/udbydere/\d+/admin/rabatter}))
    expect(Discount.count).to(eq(1)) # the preflight data is still in place for the recording
  end

  it "shows a validation error with its fix and lets the person stop" do
    answers = [
      "lead with a bad priority", "new file", target.to_s,
      "guest", # not signed in
      "lead", "lead", "", "1", "priority=urgent", "", "",
      "root_path", "da",
      "", "", "desktop", "", "", "", "",
      "n" # do not edit -> abort
    ]
    expect { run_tui(answers) }.to(raise_error(MagicTest::Wizard::TUI::Abort))
    expect(output.string).to(include("The plan is not valid:", "\"urgent\" is not a priority value.", "fix: one of: low, normal, high"))
    expect(File.exist?(target)).to(be(false))
  end
end
