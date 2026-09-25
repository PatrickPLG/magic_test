require "magic_test/wizard"
require "json"

module MagicTest
  module Wizard
    # The browser front end's server side: the entry example opens
    # /__magic_test/new in the first window and blocks on a command queue,
    # exactly like the recording session. The page reads the catalogue,
    # previews the skeleton, runs preflight (in this example, in a second
    # window that then becomes the recording window) and starts recording.
    class BrowserSession
      MAIN_THREAD_COMMANDS = %w[preflight start cancel].freeze
      Command = Struct.new(:name, :params, :result_queue)

      attr_reader :runner, :context, :catalogue, :status, :plan, :last_preflight, :call_site

      class << self
        attr_accessor :current
      end

      def initialize(runner)
        @runner = runner
        @context = runner.context
        @catalogue = runner.catalogue
        @queue = Queue.new
        @status = "planning"
        @plan = nil
        @last_preflight = nil
        @errors = []
        @preflight_window = nil
      end

      def run
        self.class.current = self
        page = context.page
        page.visit("/__magic_test/new")
        puts "\nmagic_test #{MagicTest::VERSION} wizard: open /__magic_test/new in the Chrome window (it is already there)."
        @scripted = start_script if ENV["MAGIC_TEST_WIZARD_SCRIPT"].present?
        loop do
          command = @queue.pop
          result = process(command)
          command.result_queue << result
          break if %w[recording cancelled].include?(@status)
        end
        raise Wizard::Error, "wizard cancelled" if @status == "cancelled"
        wizard_window = page.windows.first if page.windows.size > 1
        if @preflight_window
          page.switch_to_window(@preflight_window)
          front!
        end
        wizard_window&.close if wizard_window && wizard_window != page.current_window
        runner.record(call_site, plan)
      ensure
        self.class.current = nil
        @scripted&.join(5)
      end

      # ---- HTTP-facing API (called from Puma threads) --------------------------

      def catalogue_payload
        catalogue.to_h.merge(suggested_path: Wizard.suggest_path(nil, ""), viewports: Plan::Extras::VIEWPORTS,
          defaults: {locale: I18n.default_locale.to_s, locales: I18n.available_locales.map(&:to_s), sidekiq: defined?(Sidekiq::Testing) ? true : false, flipper: defined?(Flipper) ? true : false},
          target: ENV["MAGIC_TEST_WIZARD_TARGET"].presence, version: MagicTest::VERSION)
      end

      # Validate + skeleton preview; never touches the browser.
      def preview(plan_hash)
        plan = Plan.from_h(plan_hash)
        validator = runner.validate(plan)
        spec_file = runner.spec_file_for(plan)
        blocks = spec_file ? spec_file.all_blocks.map(&:to_h) : []
        skeleton = validator.valid? ? runner.codegen_for(plan).skeleton : nil
        {ok: validator.valid?, issues: validator.issues.map(&:to_h), plan: plan.to_h, skeleton: skeleton&.to_h, blocks: blocks, path: runner.path_for(plan), file_exists: !spec_file.nil?}
      rescue => e
        {ok: false, issues: [{severity: "error", field: "plan", message: "#{e.class}: #{e.message}", fix: nil}], plan: plan_hash}
      end

      def enqueue(name, params)
        if MAIN_THREAD_COMMANDS.include?(name)
          command = Command.new(name, params, Queue.new)
          @queue << command
          command.result_queue.pop(timeout: 120) || {ok: false, error: "#{name} timed out"}
        elsif name == "preview"
          preview(params["plan"] || {})
        else
          {ok: false, error: "unknown command #{name}"}
        end
      end

      def state_payload
        {status: @status, plan: plan&.to_h, preflight: last_preflight&.to_h, call_site: call_site&.to_h, errors: @errors}
      end

      private

      def process(command)
        case command.name
        when "preflight" then run_preflight(command.params["plan"] || {})
        when "start" then start(command.params["plan"] || {})
        when "cancel"
          @status = "cancelled"
          {ok: true}
        end
      rescue => e
        @errors << "#{e.class}: #{e.message}"
        {ok: false, error: "#{e.class}: #{e.message}"}
      end

      def run_preflight(plan_hash)
        @status = "preflighting"
        plan = Plan.from_h(plan_hash)
        validator = runner.validate(plan)
        unless validator.valid?
          @status = "planning"
          return {ok: false, issues: validator.issues.map(&:to_h)}
        end
        codegen = runner.codegen_for(plan)
        page = context.page
        page.switch_to_window(page.windows.first)
        result = runner.preflight(codegen, new_window: @preflight_window.nil?)
        @preflight_window = page.current_window if page.windows.size > 1
        page.switch_to_window(page.windows.first)
        front! # a background window is neither visible to the person nor capturable by Chrome
        @plan = plan
        @last_preflight = result
        @status = result.ok ? "preflighted" : "planning"
        puts "magic_test wizard: #{result.summary}"
        {ok: result.ok, preflight: result.to_h, issues: validator.warnings.map(&:to_h)}
      end

      def start(plan_hash)
        plan = Plan.from_h(plan_hash)
        unless @last_preflight&.ok && @plan && @plan.to_h == plan.to_h
          return {ok: false, error: "run preflight on this exact plan first"}
        end
        codegen = runner.codegen_for(plan)
        @call_site = runner.write(codegen)
        @status = "recording"
        {ok: true, call_site: @call_site.to_h}
      end

      # Ferrum 0.15 has no bring_to_front; activate the current target over CDP.
      def front!
        browser = context.page.driver.browser
        browser.command("Target.activateTarget", targetId: browser.page.target_id)
      rescue => e
        MagicTest.logger.warn("magic_test wizard: bring_to_front failed: #{e.message}")
      end

      # A scripted driver for the wizard page itself (the UI specs), in a
      # thread, exactly like ScriptedSession drives the recorder.
      def start_script
        require "magic_test/testing/scripted_human"
        session = self
        Thread.new do
          Thread.current.name = "magic_test-wizard-script"
          Thread.current.report_on_exception = false
          begin
            dsl = ScriptDSL.new(session)
            dsl.instance_eval(File.read(ENV["MAGIC_TEST_WIZARD_SCRIPT"]), ENV["MAGIC_TEST_WIZARD_SCRIPT"], 1)
          rescue Exception => e # rubocop:disable Lint/RescueException
            warn "magic_test wizard script failed: #{e.class}: #{e.message}\n#{Array(e.backtrace).first(6).join("\n")}"
            session.enqueue("cancel", {})
          end
        end
      end

      class ScriptDSL
        attr_reader :session

        def initialize(session)
          @session = session
        end

        def page
          session.context.page
        end

        def human
          @human ||= MagicTest::Testing::ScriptedHuman.new(page)
        end

        def state
          session.state_payload
        end

        def wait_until(timeout: 20)
          deadline = Time.now + timeout
          loop do
            return true if yield
            raise "timed out (#{timeout}s) waiting in the wizard script" if Time.now > deadline
            sleep 0.1
          end
        end

        # A value inside the wizard page (plain JS, no MagicTest globals there).
        def evaluate(js)
          page.evaluate_script(js)
        end
      end
    end
  end
end
