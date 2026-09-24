require "rails_helper"
require "timeout"
require "tmpdir"

# Phase 0 audit, Ruby side. Each example is named after the item in the task's
# section 1 list. They were written against the legacy MagicTest::Support and
# stay as regression tests for the rewrite (docs/AUDIT.md).
RSpec.describe("Audit: Ruby side of the recorder") do
  let(:page) { double("page") }
  let(:support) do
    klass = Class.new do
      include MagicTest::Support
      attr_reader :page
      def initialize(page)
        @page = page
        @test_lines_written = 0
      end
    end
    klass.new(page)
  end

  def compile(lines)
    RubyVM::InstructionSequence.compile(Array(lines).join("\n"))
  end

  describe "audit #1: within blocks" do
    it "emits a within block for a scoped event" do
      event = {"scopeType" => "within", "scopeSelector" => "'#lead_3'", "action" => "find", "target" => "'.js-star'", "options" => ".click"}
      lines = support.send(:generate_action_code, event, "")
      expect(lines.join("\n")).to(match(/within\(/))
    end
  end

  describe "audit #2: highlight-to-assert" do
    it "generates a have_content expectation instead of silently dropping it" do
      event = {"action" => "expect(page).to have_content 'Alle arrangementer'", "target" => "", "options" => ""}
      lines = support.send(:generate_action_code, event, "")
      expect(lines.join).to(include("have_content"))
    end
  end

  describe "audit #7: Ruby literal escaping" do
    it "fill_in with an apostrophe in the value is valid Ruby" do
      lines = support.send(:generate_action_code, {"action" => "fill_in", "target" => "'Navn'", "options" => "Studiz' fest"}, "")
      expect { compile(lines) }.not_to(raise_error)
    end

    it "select with an apostrophe in the option is valid Ruby" do
      lines = support.send(:generate_action_code, {"action" => "select", "target" => "'Status'", "options" => "Ja, tak' os"}, "")
      expect { compile(lines) }.not_to(raise_error)
    end

    it "chosen search/select/deselect with quotes and backslashes are valid Ruby" do
      %w[magic_choose_select magic_choose_search magic_choose_deselect].each do |action|
        lines = support.send(:generate_action_code, {"action" => action, "target" => "discount_category_ids", "options" => "Kaffe 'og' \\ te"}, "")
        expect { compile(lines) }.not_to(raise_error)
      end
    end
  end

  describe "audit #22: inserting generated code into the spec file" do
    def with_spec_file(content)
      Dir.mktmpdir do |dir|
        # a path containing /spec/ so the legacy get_last_caller accepts it
        path = File.join(dir, "spec", "system", "sample_spec.rb")
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
        yield path
      end
    end

    # Reproduces `flush` being invoked with the given file/line as the call site.
    def flush_from(path, line, events)
      allow(page).to(receive(:evaluate_script).with("sessionStorage.getItem('testingOutput')").and_return(JSON.generate(events)))
      allow(page).to(receive(:evaluate_script).with(/setItem/))
      src = ("\n" * (line - 1)) + "flush\n"
      support.instance_eval(src, path, 1)
    end

    it "inserts directly above the magic_test line even after the editor inserted lines above it" do
      with_spec_file("  it 'x' do\n    magic_test\n  end\n") do |path|
        flush_from(path, 2, [{"action" => "click_on", "target" => "'A'", "options" => ""}])
        # the developer's editor saves a new line at the top of the file mid-session
        File.write(path, "require 'rails_helper'\n" + File.read(path))
        flush_from(path, 4, [{"action" => "click_on", "target" => "'B'", "options" => ""}])
        lines = File.read(path).lines.map(&:strip)
        expect(lines.index("click_on 'B'")).to(eq(lines.index("magic_test") - 1))
      end
    end

    it "works when magic_test is on line 1" do
      with_spec_file("magic_test\n") do |path|
        expect {
          flush_from(path, 1, [{"action" => "click_on", "target" => "'A'", "options" => ""}])
        }.not_to(raise_error)
      end
    end

    it "`ok` works when magic_test is the last line of the file" do
      with_spec_file("it 'x' do\nmagic_test") do |path|
        allow(support).to(receive(:get_last).and_return(["click_on 'A'"]))
        expect {
          support.instance_eval("\nok\n", path, 1)
        }.not_to(raise_error)
      end
    end

    it "does not leak file handles" do
      with_spec_file("it 'x' do\n  magic_test\nend\n") do |path|
        flush_from(path, 2, [{"action" => "click_on", "target" => "'A'", "options" => ""}])
        leaked = ObjectSpace.each_object(File).select { |f| !f.closed? && f.path == path }
        expect(leaked).to(be_empty)
      end
    end
  end

  describe "audit #23: locating the calling spec file" do
    it "uses the nearest frame, even when magic_test is called from a support file whose name contains 'helper'" do
      frames = [
        "/app/spec/support/system_auth_helper.rb:10:in `login_and_record'",
        "/app/spec/system/foo_spec.rb:20:in `block (2 levels)'"
      ]
      expect(support.send(:get_last_caller, frames)).to(eq(["/app/spec/support/system_auth_helper.rb", "10"]))
    end

    it "does not crash when the project path contains 'helper'" do
      frames = ["/home/dev/helper-tools/spec/system/foo_spec.rb:20:in `block'"]
      expect(support.send(:get_last_caller, frames)).to(eq(["/home/dev/helper-tools/spec/system/foo_spec.rb", "20"]))
    end
  end

  describe "audit #24: magic_test error handling" do
    it "does not retry forever on a deterministic exception" do
      ENV["MAGIC_TEST"] = "1"
      allow(support).to(receive(:empty_cache))
      allow(support).to(receive(:magic_test_pry_hook).and_raise(RuntimeError, "boom"))
      allow(support).to(receive(:puts))
      expect {
        Timeout.timeout(2) { support.magic_test }
      }.to(raise_error(RuntimeError, "boom"))
    ensure
      ENV.delete("MAGIC_TEST")
    end
  end

  describe "audit #25: exe/magic" do
    it "runs only the given spec files, with bundle exec, quoting paths with spaces" do
      Dir.mktmpdir do |dir|
        fake_bin = File.join(dir, "bin")
        FileUtils.mkdir_p(fake_bin)
        log = File.join(dir, "args.log")
        File.write(File.join(fake_bin, "rspec"), "#!/bin/sh\nprintf '%s\\n' \"$@\" > #{log}\n")
        File.write(File.join(fake_bin, "bundle"), "#!/bin/sh\nshift\nexec \"$@\"\n") # `bundle exec rspec ...`
        FileUtils.chmod(0o755, [File.join(fake_bin, "rspec"), File.join(fake_bin, "bundle")])
        system({"PATH" => "#{fake_bin}:#{ENV["PATH"]}"}, "ruby", File.expand_path("../../exe/magic", __dir__),
          "spec", "spec/system/my spec_spec.rb", "spec/system/other_spec.rb", out: File::NULL, err: File::NULL)
        args = File.exist?(log) ? File.read(log).lines.map(&:chomp) : []
        expect(args).to(eq(["spec/system/my spec_spec.rb", "spec/system/other_spec.rb"]))
      end
    end
  end

  describe "audit #26: helpers are available without MAGIC_TEST", type: :system do
    it "includes the gem helpers into type: :system specs when MAGIC_TEST is unset" do
      expect(ENV["MAGIC_TEST"]).to(be_nil)
      expect(self.class.ancestors.map(&:to_s)).to(include("MagicTest::Helpers"))
    end
  end

  describe "audit #27: the gem has a real test suite" do
    it "no longer ships the placeholder test" do
      expect(File.exist?(File.expand_path("../../test/magic_test_test.rb", __dir__))).to(be(false))
    end
  end

  describe "audit #28: partial hygiene" do
    it "has no <script text=...> typo in the recorder markup" do
      views = Dir[File.expand_path("../../app/views/**/*", __dir__)].select { |f| File.file?(f) }
      offenders = views.select { |f| File.read(f).include?('<script text="text/javascript">') }
      expect(offenders).to(be_empty)
    end
  end
end
