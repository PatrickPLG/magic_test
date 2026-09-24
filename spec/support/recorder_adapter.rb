# Adapters that turn "a person did X in the browser" into the Ruby lines the
# recorder would write. The audit specs are written against this interface so
# they can run unchanged against the legacy recorder and the rewrite.
module RecorderAdapters
  # The recorder shipped on branch semantic-selector-improvements: view
  # partials that push pre-built code fragments into sessionStorage, and
  # MagicTest::Support#flush that splices them into the calling file.
  class Legacy
    include MagicTest::Support

    attr_reader :page

    def initialize(page)
      @page = page
      @test_lines_written = 0
    end

    def start
      empty_cache # what the legacy `magic_test` does first
    end

    # Legacy: Ctrl+Shift+A (the JS then calls window.confirm, which Cuprite accepts).
    def assert_selection(human)
      human.press("A", :control, :shift)
    end

    # Legacy: nothing to answer, Cuprite auto-accepts every dialog.
    def answer_dialog(_human, _answer)
    end

    def raw_events
      JSON.parse(page.evaluate_script("sessionStorage.getItem('testingOutput')") || "[]")
    end

    # Runs the real legacy `flush` against a scratch file so its caller-frame
    # arithmetic points at that file, then returns what it wrote there.
    def lines
      dir = File.expand_path("../audit/tmp", __dir__)
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "legacy_flush_#{SecureRandom.hex(4)}.rb")
      File.write(path, "# legacy flush target\nflush\n")
      eval(File.read(path), binding, path, 1) # rubocop:disable Security/Eval
      File.read(path).lines.map(&:chomp).reject { |l| ["# legacy flush target", "flush", ""].include?(l) }.map(&:strip)
    ensure
      File.delete(path) if path && File.exist?(path)
    end
  end
end

module RecorderAdapterHelpers
  def recorder
    @recorder ||= RecorderAdapters::Legacy.new(page)
  end

  def human
    @human ||= MagicTest::Testing::ScriptedHuman.new(page)
  end

  # Records whatever the block does and returns the generated Ruby lines.
  def record
    recorder.start
    yield human
    settle
    recorder.lines
  end

  # Gives the page a moment to flush change/blur events before reading.
  def settle
    page.execute_script("document.activeElement && document.activeElement.blur && document.activeElement.blur()")
    sleep 0.2
  end

  def valid_ruby?(lines)
    RubyVM::InstructionSequence.compile(lines.join("\n"))
    true
  rescue SyntaxError
    false
  end
end

RSpec.configure do |config|
  config.include RecorderAdapterHelpers, :recorder
  config.around(:each, :recorder) do |example|
    previous = ENV["MAGIC_TEST"]
    ENV["MAGIC_TEST"] = "1" # the legacy partial checks this at render time
    example.run
  ensure
    ENV["MAGIC_TEST"] = previous
  end
end
