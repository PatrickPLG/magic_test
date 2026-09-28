require "rails_helper"
require "open3"

# The browser wizard end to end: the entry example opens /__magic_test/new in
# headless Chrome, a scripted human fills the form, runs preflight (second
# window) and starts recording; the written file is checked afterwards.
RSpec.describe("Browser wizard", :recorder, type: :system) do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:work) { File.join(root, "tmp", "wizard_ui") }

  before do
    studiz_driven_by
    FileUtils.rm_rf(work)
  end

  def run_wizard(script, target:, db:, record_script: "record_script.rb")
    FileUtils.mkdir_p(File.dirname(target))
    env = {
      "MAGIC_TEST" => "1", "MAGIC_TEST_HEADLESS" => "1", "MAGIC_TEST_WIZARD" => "browser",
      "MAGIC_TEST_WIZARD_SCRIPT" => File.join(root, "spec/fixtures/wizard/ui", script),
      "MAGIC_TEST_SCRIPT" => File.join(root, "spec/fixtures/wizard/ui", record_script),
      "MAGIC_TEST_UI_TARGET" => target, "MAGIC_TEST_WIZARD_TARGET" => target,
      "FIXTURE_APP_DB" => File.join(work, db), "RAILS_ENV" => "test"
    }
    out, status = Open3.capture2e(env, "bin/rspec", File.join(root, "lib/magic_test/wizard/entry_spec.rb"), chdir: root)
    File.write(File.join(work, "#{script}.log"), out)
    [out, status]
  end

  it "writes a new provider spec from the form and hands over to the recorder" do
    target = File.join(work, "spec/system/provider/renames_spec.rb")
    out, status = run_wizard("new_file_script.rb", target: target, db: "new.sqlite3")
    expect(status.success?).to(be(true), out.lines.last(40).join)
    expect(out).to(include("preflight", "recording starts now", "session finished"))
    written = File.read(target)
    expect(written).to(include(
      "RSpec.describe('Provider renames a discount', :js, type: :system) do",
      "let!(:provider) { create(:provider, :with_cvr) }",
      "let!(:discount) { create(:discount, :active, provider: provider) }",
      "magic_sign_in(provider.user)",
      "visit(provider_admin_discounts_path(provider))"
    ))
    expect(written.lines.map(&:strip)).to(include("magic_test"))
  end

  it "appends an example to an existing Studiz-style file, reusing its lets" do
    target = File.join(work, "spec/system/provider/discounts_spec.rb")
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(File.join(root, "spec/fixtures/wizard/provider_discounts_spec.rb.txt"), target)
    FileUtils.mkdir_p(File.join(work, "spec/support"))
    File.write(File.join(work, "spec/support/system_auth_helper.rb"), "require #{File.join(root, "spec/support/system_auth_helper").inspect}\n")
    out, status = run_wizard("append_script.rb", target: target, db: "append.sqlite3")
    expect(status.success?).to(be(true), out.lines.last(40).join)
    written = File.read(target)
    original = File.read(File.join(root, "spec/fixtures/wizard/provider_discounts_spec.rb.txt"))
    expect(written).to(start_with(original.sub(/end\n\z/, "")))
    expect(written).to(include("\n  it 'provider lists the discounts again' do\n    visit(provider_admin_discounts_path(provider))\n    magic_test\n  end\nend\n"))
    expect(written.scan("let!(:discount)").size).to(eq(1)) # reused, not duplicated
  end

  # B5 (1.2): on the real app clicking a trait's label text or row did not
  # toggle it (nested labels: the group wrapper was a <label> too).
  it "toggles a trait from its label text or its row, exactly one, and shows removable chips" do
    out, = run_wizard("trait_rows_script.rb", target: File.join(work, "spec/system/provider/traits_spec.rb"), db: "traits.sqlite3")
    expect(out).to(include("B5 OK: label text and row toggle exactly one trait; chips add and remove"), out.lines.grep(/script failed|B5|Error/).join)
  end

  # B9 (1.2): after Start the wizard page only said "recording". It must stay
  # open as a status screen: where the recording runs, what file it writes,
  # a live step count, and Save / Save & finish that act on the recording.
  it "keeps the wizard window as a status screen that mirrors the recording" do
    target = File.join(work, "spec/system/provider/status_spec.rb")
    out, status = run_wizard("new_file_script.rb", target: target, db: "status.sqlite3", record_script: "status_screen_record_script.rb")
    expect(out).to(include("B9 OK: status screen shows the file, the live step count and finishes the recording"), out.lines.grep(/script|B9|Error|error/).first(12).join)
    expect(status.success?).to(be(true), out.lines.last(40).join)
    written = File.read(target)
    expect(written).to(include("click_on(I18n.t('discounts.index.edit'))"))
    expect(out).to(include("session finished (1 step(s), 1 saved)")) # Save & finish from the status screen ended the session
  end
end
