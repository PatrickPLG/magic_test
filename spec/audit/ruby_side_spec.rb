require "rails_helper"
require "magic_test/session"
require "timeout"
require "tmpdir"

# Phase 0 audit, Ruby side. Each example is named after the item in the task's
# section 1 list. They were first written against the legacy MagicTest::Support
# (see git history, commit 771af00, and docs/AUDIT.md) and now exercise the
# rewrite's API with the same intent.
RSpec.describe("Audit: Ruby side of the recorder") do
  let(:session) { FakeSession.new(known_ids: ["3"]) }

  def compile(lines)
    RubyVM::InstructionSequence.compile(Array(lines).join("\n"))
  end

  describe "audit #1: within blocks" do
    it "emits a within block for a scoped event" do
      event = ev("click", role: "other", target: target(tag: "button"),
        candidates: [cand(kind: "css", by: "class", locator: "button.js-star", exact: 3, partial: 3),
          cand(kind: "css", by: "class", locator: "button.js-star", exact: 1, partial: 1, scope: {"kind" => "row", "css" => "tr", "text" => "Lead 2"})])
      lines = session.lines([event])
      expect(lines.join("\n")).to(match(/within\('tr', text: 'Lead 2'\) do\n  find\('button\.js-star'\)\.click\nend/))
    end
  end

  describe "audit #2: highlight-to-assert" do
    it "generates a have_content expectation instead of silently dropping it" do
      event = ev("assert", assertion: {"type" => "content", "text" => "Alle arrangementer", "occurrences" => 1})
      lines = session.lines([event])
      expect(lines.join).to(include("have_content"))
      expect(lines.join).to(include("I18n.t('events.index.title')"))
    end
  end

  describe "audit #7: Ruby literal escaping" do
    it "fill_in with an apostrophe in the value is valid Ruby" do
      event = ev("fill", value: "Studiz' fest", target: target(tag: "input", name: "x"), candidates: [cand(kind: "fillable_field", by: "label", locator: "Navn")])
      lines = session.lines([event])
      expect(lines).to(eq(["fill_in(I18n.t('activerecord.attributes.discount.name_da'), with: \"Studiz' fest\")"]).or(include(match(/fill_in\(.*with: "Studiz' fest"\)/))))
      expect { compile(lines) }.not_to(raise_error)
    end

    it "select with an apostrophe in the option is valid Ruby" do
      event = ev("select", added: ["Ja, tak' os"], selected: ["Ja, tak' os"], target: target(tag: "select"), candidates: [cand(kind: "select", by: "label", locator: "Status")])
      lines = session.lines([event])
      expect(lines.last).to(match(/\Aselect\("Ja, tak' os", from: .*\)\z/))
      expect { compile(lines) }.not_to(raise_error)
    end

    it "chosen select/unselect with quotes and backslashes are valid Ruby" do
      %w[select unselect].each do |action|
        event = ev("chosen", action: action, option: "Kaffe 'og' \\ te", target: target(tag: "select"), candidates: [cand(kind: "select", by: "id", locator: "discount_category_ids")])
        lines = session.lines([event])
        expect(lines.first).to(include("\"Kaffe 'og' \\\\ te\""))
        expect { compile(lines) }.not_to(raise_error)
      end
    end
  end

  describe "audit #22: inserting generated code into the spec file" do
    def with_spec_file(content)
      Dir.mktmpdir do |dir|
        path = File.join(dir, "spec", "system", "sample_spec.rb")
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
        yield path
      end
    end

    it "inserts directly above the magic_test line even after the editor inserted lines above it" do
      with_spec_file("  it 'x' do\n    magic_test\n  end\n") do |path|
        writer = MagicTest::SpecWriter.new(path: path, line: 2, source_line: "    magic_test")
        writer.insert_above(["click_on('A')"])
        File.write(path, "require 'rails_helper'\n" + File.read(path))
        writer.insert_above(["click_on('B')"])
        lines = File.read(path).lines.map(&:strip)
        expect(lines.index("click_on('B')")).to(eq(lines.index("magic_test") - 1))
        expect(File.read(path)).to(eq("require 'rails_helper'\n  it 'x' do\n    click_on('A')\n    click_on('B')\n    magic_test\n  end\n"))
      end
    end

    it "works when magic_test is on line 1" do
      with_spec_file("magic_test\n") do |path|
        writer = MagicTest::SpecWriter.new(path: path, line: 1, source_line: "magic_test")
        expect { writer.insert_above(["click_on('A')"]) }.not_to(raise_error)
        expect(File.read(path)).to(eq("click_on('A')\nmagic_test\n"))
      end
    end

    it "`ok` works when magic_test is the last line of the file" do
      with_spec_file("x = 1\nmagic_test") do |path|
        writer = MagicTest::SpecWriter.new(path: path, line: 2, source_line: "magic_test")
        expect { writer.insert_above(["click_on('A')"]) }.not_to(raise_error)
        expect(File.read(path)).to(eq("x = 1\nclick_on('A')\nmagic_test"))
      end
    end

    it "does not leak file handles" do
      with_spec_file("it 'x' do\n  magic_test\nend\n") do |path|
        MagicTest::SpecWriter.new(path: path, line: 2, source_line: "  magic_test").insert_above(["click_on('A')"])
        leaked = ObjectSpace.each_object(File).select { |f| !f.closed? && f.path == path }
        expect(leaked).to(be_empty)
      end
    end

    it "refuses to write code that would not parse and leaves the file untouched" do
      with_spec_file("it 'x' do\n  magic_test\nend\n") do |path|
        writer = MagicTest::SpecWriter.new(path: path, line: 2, source_line: "  magic_test")
        expect { writer.insert_above(["click_on('A'"]) }.to(raise_error(MagicTest::SpecWriter::Error, /refusing to write/))
        expect(File.read(path)).to(eq("it 'x' do\n  magic_test\nend\n"))
      end
    end
  end

  describe "audit #23: locating the calling spec file" do
    let(:location) { Struct.new(:path, :lineno) }

    it "uses the nearest frame, even when magic_test is called from a support file whose name contains 'helper'" do
      frames = [location.new("/app/spec/support/system_auth_helper.rb", 10), location.new("/app/spec/system/foo_spec.rb", 20)]
      site = MagicTest::CallSite.capture(frames)
      expect([site.path, site.line]).to(eq(["/app/spec/support/system_auth_helper.rb", 10]))
    end

    it "does not crash when the project path contains 'helper'" do
      frames = [location.new("/home/dev/helper-tools/spec/system/foo_spec.rb", 20)]
      site = MagicTest::CallSite.capture(frames)
      expect([site.path, site.line]).to(eq(["/home/dev/helper-tools/spec/system/foo_spec.rb", 20]))
    end

    it "skips the gem's own frames" do
      frames = [location.new("/gems/magic_test/lib/magic_test/helpers.rb", 5), location.new("/app/spec/system/foo_spec.rb", 20)]
      site = MagicTest::CallSite.capture(frames)
      expect(site.path).to(eq("/app/spec/system/foo_spec.rb"))
    end
  end

  describe "audit #24: magic_test error handling" do
    it "does not retry forever on a deterministic exception" do
      site = MagicTest::CallSite.new(path: "/tmp/x_spec.rb", line: 1, source_line: "magic_test")
      allow_any_instance_of(MagicTest::Session).to(receive(:start).and_raise(RuntimeError, "boom"))
      expect {
        Timeout.timeout(2) { MagicTest::Session.run(page: double("page"), call_site: site) }
      }.to(raise_error(RuntimeError, "boom"))
      expect(MagicTest.current_session).to(be_nil)
    end
  end

  describe "audit #25: exe/magic" do
    it "runs only the given spec files, with bundle exec, quoting paths with spaces" do
      Dir.mktmpdir do |dir|
        fake_bin = File.join(dir, "bin")
        FileUtils.mkdir_p(fake_bin)
        log = File.join(dir, "args.log")
        File.write(File.join(fake_bin, "rspec"), "#!/bin/sh\nprintf '%s\\n' \"$@\" > #{log}\necho \"MAGIC_TEST=$MAGIC_TEST\" >> #{log}\n")
        File.write(File.join(fake_bin, "bundle"), "#!/bin/sh\nshift\nexec \"$@\"\n")
        FileUtils.chmod(0o755, [File.join(fake_bin, "rspec"), File.join(fake_bin, "bundle")])
        specs = [File.join(dir, "spec/system/my spec_spec.rb"), File.join(dir, "spec/system/other_spec.rb")]
        specs.each { |s| FileUtils.mkdir_p(File.dirname(s)) && File.write(s, "") }
        # Outside Bundler's environment: under `bundle exec` (CI) Bundler
        # prepends the bundle's bin dir to PATH, so the real rspec would win.
        Bundler.with_unbundled_env do
          system({"PATH" => "#{fake_bin}:#{ENV["PATH"]}"}, "ruby", File.expand_path("../../exe/magic", __dir__), "spec", *specs, out: File::NULL, err: File::NULL)
        end
        args = File.exist?(log) ? File.read(log).lines.map(&:chomp) : []
        expect(args).to(eq(specs + ["MAGIC_TEST=1"]))
      end
    end

    it "refuses a missing file instead of running the whole suite" do
      out = `ruby #{File.expand_path("../../exe/magic", __dir__)} spec spec/system/nope_spec.rb 2>&1`
      expect($?.exitstatus).to(eq(2))
      expect(out).to(include("no such file"))
    end
  end

  describe "audit #26: helpers are available without MAGIC_TEST", :no_recorder, type: :system do
    it "includes the gem helpers into type: :system specs when MAGIC_TEST is unset" do
      expect(ENV["MAGIC_TEST"]).to(be_nil)
      expect(self.class.ancestors.map(&:to_s)).to(include("MagicTest::Helpers"))
      expect(self).to(respond_to(:magic_chosen_select))
      expect(self).to(respond_to(:magic_test))
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

    it "ships only the no-op shim partial" do
      views = Dir[File.expand_path("../../app/views/magic_test/*", __dir__)].map { |f| File.basename(f) }
      expect(views).to(eq(["_support.html.erb"]))
    end
  end
end
