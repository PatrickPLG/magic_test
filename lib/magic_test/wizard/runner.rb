require "magic_test/wizard"
require "magic_test/wizard/preflight"
require "magic_test/wizard/writer"
require "magic_test/session"

module MagicTest
  module Wizard
    # Orchestrates one wizard run inside the entry example: a front end
    # produces the Plan, preflight proves it, the skeleton is written and the
    # recorder starts in the same session and window.
    class Runner
      attr_reader :context, :catalogue

      def self.run(context)
        new(context).run
      end

      def initialize(context)
        @context = context
        @catalogue = Catalogue.current
      end

      def mode
        (ENV["MAGIC_TEST_WIZARD"].presence || "browser").to_s
      end

      def run
        case mode
        when "plan" then run_plan
        when "tui"
          require "magic_test/wizard/tui"
          TUI.new(self).run
        else
          require "magic_test/wizard/browser_session"
          BrowserSession.new(self).run
        end
      end

      # ---- shared steps --------------------------------------------------------

      def path_for(plan)
        Wizard.resolve_path(plan.target.path, root: catalogue.root)
      end

      def spec_file_for(plan)
        path = path_for(plan)
        File.exist?(path) ? SpecFile.parse(path) : nil
      end

      def codegen_for(plan)
        Codegen.new(plan, catalogue, spec_file: spec_file_for(plan))
      end

      def validate(plan)
        Validator.validate(plan, catalogue)
      end

      def preflight(codegen, new_window: false)
        @preflight = Preflight.new(codegen, context: context)
        result = @preflight.run(new_window: new_window)
        record_starter_status(codegen.plan, result)
        result
      end

      # Starters remember their last preflight (tmp/magic_test/starters_status.json).
      def record_starter_status(plan, result)
        return unless plan.starter
        Starters.record_status(catalogue.root, plan.starter, ok: result.ok, message: result.ok ? nil : result.failures.first.to_s)
      end

      # `bin/magic new --template <name> "description"`: the template's plan with the new description.
      def template_plan
        name = ENV["MAGIC_TEST_WIZARD_TEMPLATE"].presence or return nil
        plan = Templates.load(name, catalogue.root)
        plan.description = ENV["MAGIC_TEST_WIZARD_DESCRIPTION"].to_s if ENV["MAGIC_TEST_WIZARD_DESCRIPTION"].present?
        plan.target = Plan::Target.new(path: ENV["MAGIC_TEST_WIZARD_TARGET"], block: nil) if ENV["MAGIC_TEST_WIZARD_TARGET"].present?
        plan
      end

      # The plan of the previous run (tmp/magic_test/last_plan.yml), if any.
      def last_plan
        path = catalogue.root.join("tmp/magic_test/last_plan.yml")
        path.exist? ? Plan.load(path.to_s) : nil
      rescue => e
        MagicTest.logger.warn("magic_test wizard: could not read #{path}: #{e.message}")
        nil
      end

      attr_reader :last_preflight

      # Writes the skeleton and returns the call site the recorder writes above.
      def write(codegen)
        written = Writer.write(codegen.skeleton, path_for(codegen.plan))
        puts "magic_test wizard: the previous #{File.basename(written.path)} is backed up at #{written.backup}" if written.backup
        save_plan(codegen.plan)
        MagicTest::CallSite.new(path: written.path, line: written.line, source_line: written.source_line, example_line: nil, example_description: codegen.plan.description)
      end

      def record(call_site, plan = nil)
        puts "magic_test wizard: wrote #{call_site.path}:#{call_site.line}; recording starts now."
        run_session = -> { MagicTest::Session.run(page: context.page, call_site: call_site, example: (defined?(RSpec) ? RSpec.current_example : nil), context: context) }
        # The written spec wraps its steps in Sidekiq::Testing.inline!; the recording must behave the same.
        if plan&.extras&.sidekiq_inline && defined?(Sidekiq::Testing)
          Sidekiq::Testing.inline!(&run_session)
        else
          run_session.call
        end
      end

      def save_plan(plan)
        dir = catalogue.root.join("tmp/magic_test")
        FileUtils.mkdir_p(dir)
        File.write(dir.join("last_plan.yml"), plan.to_yaml)
      rescue => e
        MagicTest.logger.warn("magic_test wizard: could not save the plan: #{e.message}")
      end

      def format_issues(issues)
        issues.map { |i| "  - #{i.field}: #{i.message}#{" (fix: #{i.fix})" if i.fix}" }.join("\n")
      end

      # ---- --plan plan.yml (non-interactive) -----------------------------------

      def run_plan
        plan_path = ENV["MAGIC_TEST_WIZARD_PLAN"].presence or raise Wizard::Error, "MAGIC_TEST_WIZARD_PLAN is not set"
        plan = Plan.load(plan_path)
        validator = validate(plan)
        raise Wizard::Error, "the plan is not valid:\n#{format_issues(validator.errors)}" unless validator.valid?
        puts "magic_test wizard: warnings:\n#{format_issues(validator.warnings)}" if validator.warnings.any?
        puts "magic_test wizard: hints:\n#{format_issues(validator.hints)}" if validator.hints.any?
        codegen = codegen_for(plan)
        skeleton = codegen.skeleton
        puts "magic_test wizard: skeleton (#{skeleton.mode}) for #{path_for(plan)}:\n#{skeleton.body_lines.map { |l| "    #{l}" }.join("\n")}"
        result = preflight(codegen)
        puts "magic_test wizard: #{result.summary}"
        raise Wizard::Error, result.summary unless result.ok
        record(write(codegen), plan)
      end
    end
  end
end
