# Adapter that turns "a person did X in the browser" into the Ruby lines the
# recorder would write. The audit specs are written against this interface;
# the legacy adapter (sessionStorage + Support#flush) lived here during Phase 0
# and is preserved in git history at commit 771af00.
module RecorderAdapters
  # The rewrite: server-side session fed by the injected recorder over HTTP.
  # The session is created directly (no blocking command loop) so the spec
  # thread can drive the page and read the generated code.
  class Server
    attr_reader :page, :session

    def initialize(page, call_site: nil)
      @page = page
      @call_site = call_site
    end

    def start
      require "magic_test/session"
      @session = MagicTest::Session.new(page: page, call_site: @call_site || scratch_call_site, context: nil)
      MagicTest.current_session = @session
      @dialogs_handled = 0
      sync_browser
    end

    def stop
      MagicTest.current_session = nil
      File.delete(@scratch_path) if @scratch_path && File.exist?(@scratch_path)
    end

    def lines
      settle
      session.pending_lines
    end

    def steps
      settle
      session.pending_steps
    end

    def raw_events
      session.event_log.all
    end

    # Alt+Shift+X in the page, exactly what a person presses.
    def assert_selection(human)
      human.press("X", :alt, :shift)
      settle
    end

    # Answers the dialog the recorder intercepted through the same command
    # endpoint the toolbar and the scripted human use.
    def answer_dialog(_human, answer)
      answered = -> { session.event_log.all.count { |e| e["kind"] == "dialog" } }
      wait_until(5) { session.state_payload["pending_dialog"] || answered.call > @dialogs_handled }
      if session.state_payload["pending_dialog"]
        session.enqueue_command("answer_dialog", "answer" => answer.to_s)
        wait_until(5) { session.state_payload["pending_dialog"].nil? }
      end
      @dialogs_handled = answered.call
      settle
    end

    def state
      session.state_payload
    end

    # Makes sure the page's recorder has picked up the session (it polls the
    # config endpoint once a second while idle).
    def sync_browser
      return unless page.current_url.start_with?("http")
      wait_until(6) do
        page.evaluate_script("window.MagicTest && window.MagicTest.status && window.MagicTest.status()") == "recording"
      end
    rescue Timeout::Error
      raise "the recorder in the page never connected to the session (status: #{page.evaluate_script("window.MagicTest && window.MagicTest.status && window.MagicTest.status()").inspect}, errors: #{page.evaluate_script("window.MagicTest && window.MagicTest.errors && window.MagicTest.errors()").inspect})"
    end

    # Lets in-flight events reach the server: commit typing, wait until the
    # browser queue is empty.
    def settle
      return unless page.current_url.start_with?("http")
      begin
        page.execute_script("document.activeElement && document.activeElement.blur && document.activeElement.blur(); if (window.MagicTest) { window.MagicTest.__internals.typing.commitAll('settle'); window.MagicTest.__internals.transport.flush(); }")
      rescue
        nil
      end
      sleep 0.35
    end

    def wait_until(seconds)
      Timeout.timeout(seconds) do
        loop do
          return true if yield
          sleep 0.05
        end
      end
    end

    private

    # A throwaway spec-shaped file (outside spec/, so RSpec never loads it).
    def scratch_call_site
      dir = File.expand_path("../../tmp/magic_test_scratch", __dir__)
      FileUtils.mkdir_p(dir)
      @scratch_path = File.join(dir, "scratch_#{SecureRandom.hex(4)}.rb")
      File.write(@scratch_path, "RSpec.describe('scratch') do\n  it 'records' do\n    magic_test\n  end\nend\n")
      MagicTest::CallSite.new(path: @scratch_path, line: 3, source_line: "    magic_test")
    end
  end
end

module RecorderAdapterHelpers
  def recorder
    @recorder ||= RecorderAdapters::Server.new(page)
  end

  def human
    @human ||= MagicTest::Testing::ScriptedHuman.new(page)
  end

  # Records whatever the block does and returns the generated Ruby lines.
  def record
    recorder.start
    yield human
    recorder.lines
  end

  def settle
    recorder.settle
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
  config.after(:each, :recorder) do
    @recorder&.stop
  end
end
