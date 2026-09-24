require "net/http"
require "uri"
require "json"

module MagicTest
  # Runs a "scripted human" against the live recording session, in a
  # background thread, so the main thread can block on the command queue like
  # it does for a person. The script drives the page with CDP-trusted input
  # (MagicTest::Testing::ScriptedHuman) and talks to the same HTTP endpoints
  # the toolbar uses.
  #
  #   MAGIC_TEST=1 MAGIC_TEST_HEADLESS=1 MAGIC_TEST_SCRIPT=path/to/script.rb rspec spec/x_spec.rb
  class ScriptedSession
    def self.start(session)
      new(session, ENV["MAGIC_TEST_SCRIPT"]).start
    end

    def initialize(session, script_path)
      @session = session
      @script_path = script_path
      require "magic_test/testing/scripted_human"
    end

    def start
      @thread = Thread.new do
        Thread.current.name = "magic_test-script"
        Thread.current.report_on_exception = false
        run
      end
      @thread
    end

    def join(timeout = nil)
      @thread&.join(timeout)
    end

    def run
      dsl = DSL.new(@session)
      dsl.instance_eval(File.read(@script_path), @script_path, 1)
      dsl.command!("save_and_finish") unless @session.finished?
    rescue Exception => e # rubocop:disable Lint/RescueException
      message = "#{e.class}: #{e.message}\n#{Array(e.backtrace).first(8).join("\n")}"
      warn "magic_test scripted session failed: #{message}"
      begin
        DSL.new(@session).command("abort", error: message)
      rescue
        nil
      end
    end

    # What a script can call.
    class DSL
      attr_reader :session

      def initialize(session)
        @session = session
      end

      def page
        session.page
      end

      def human
        @human ||= MagicTest::Testing::ScriptedHuman.new(page)
      end

      # Toolbar command, sent over HTTP exactly like the toolbar does.
      SAVE_LIKE_COMMANDS = %w[save save_and_finish replay_pending open_console].freeze

      # Sends a toolbar command straight to the server. Save-like commands
      # first commit a value still being typed and wait for the browser's
      # event queue to drain, exactly as the toolbar's Save button does.
      def command(name, **params)
        commit_typing if SAVE_LIKE_COMMANDS.include?(name.to_s)
        uri = URI.join(server_url, "/__magic_test/commands")
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = MagicTest.config.command_timeout + 5
        response = http.post(uri.path, JSON.generate({"command" => name}.merge(params.transform_keys(&:to_s))), "Content-Type" => "application/json")
        JSON.parse(response.body)
      end

      def commit_typing(timeout: 3)
        internals = "window.MagicTest && window.MagicTest.__internals"
        return unless page.evaluate_script("!!(#{internals})")
        page.execute_script("#{internals}.typing.commitAll('save'); #{internals}.transport.flush();")
        deadline = Time.now + timeout
        sleep 0.05 while page.evaluate_script("#{internals}.transport.pending()").to_i > 0 && Time.now < deadline
      rescue => e
        warn "magic_test scripted session: commit_typing skipped (#{e.class}: #{e.message})"
      end

      def state
        uri = URI.join(server_url, "/__magic_test/state")
        JSON.parse(Net::HTTP.get(uri))
      end

      # Waits until the server has turned the events into at least `count` steps.
      def wait_for_steps(count, timeout: 10)
        deadline = Time.now + timeout
        loop do
          steps = state["steps"]
          return steps if steps.size >= count
          raise "timed out waiting for #{count} step(s); have #{steps.size}: #{steps.map { |s| s["code"] }}" if Time.now > deadline
          sleep 0.1
        end
      end

      def wait_for_suggestion(text, timeout: 10)
        deadline = Time.now + timeout
        loop do
          s = state["suggestions"].find { |x| x["code"].include?(text) || x["label"].to_s.include?(text) }
          return s if s
          raise "timed out waiting for suggestion containing #{text.inspect}; have #{state["suggestions"].map { |x| x["code"] }}" if Time.now > deadline
          sleep 0.1
        end
      end

      def accept_suggestion(text, alternative: nil)
        s = wait_for_suggestion(text)
        command!("accept_suggestion", suggestion_id: s["id"], code: s["code"], alternative: alternative)
      end

      # Like `command` but fails the script when the server refuses.
      def command!(name, **params)
        result = command(name, **params)
        raise "command #{name} failed: #{result["error"] || result.inspect}" unless result["ok"]
        result
      end

      # Answers the dialog the recorder intercepted (accept/dismiss).
      def answer_dialog(answer, response: nil)
        deadline = Time.now + 10
        sleep 0.1 until state["pending_dialog"] || Time.now > deadline
        command!("answer_dialog", answer: answer.to_s, response: response)
        sleep 0.1 while state["pending_dialog"] && Time.now < deadline
      end

      # Sets the recorder mode and waits until the page has picked it up.
      def set_mode(mode, **options)
        command!("set_mode", mode: mode.to_s, **options)
        deadline = Time.now + 5
        until page.evaluate_script("window.MagicTest && window.MagicTest.modes.current()") == mode.to_s
          raise "the page did not switch to #{mode} mode" if Time.now > deadline
          sleep 0.1
        end
      end

      def settle(seconds = 0.3)
        sleep seconds
      end

      def server_url
        Capybara.current_session.server.base_url
      end
    end
  end
end
