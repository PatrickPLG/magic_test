# frozen_string_literal: true

require "fileutils"
require "open3"
require "magic_test/testing/golden_flow"

module MagicTest
  module Testing
    # A golden wizard flow: a plan (YAML), optionally an existing spec file to
    # append to, optionally a first plan that must fail preflight, and the
    # scripted human that records once the wizard hands over. The runner
    # writes the plan, runs `bin/magic new --plan` in a subprocess (through the
    # entry spec), then replays the written spec three times on fresh
    # databases, rubocops it and compares it with expected.rb.
    class WizardFlow
      REPLAYS = GoldenFlow::REPLAYS
      TARGET_PLACEHOLDER = "__TARGET__"

      class << self
        def registry
          @registry ||= {}
        end

        def define(name, &block)
          flow = new(name, file: caller_locations(1, 1).first.path)
          flow.instance_eval(&block)
          registry[name] = flow
          flow
        end

        def load_all(dir)
          Dir[File.join(dir, "*", "flow.rb")].sort.each { |f| load f }
          registry.values.sort_by(&:name)
        end
      end

      attr_reader :name, :file, :script_block, :plans, :existing_fixture, :failure_pattern

      def initialize(name, file:)
        @name = name
        @file = File.expand_path(file)
        @plans = []
        @existing_fixture = nil
        @failure_pattern = nil
        @target_name = "#{name}_spec.rb"
      end

      # --- DSL ---------------------------------------------------------------

      def plan(yaml)
        @plans << yaml
      end
      alias_method :then_plan, :plan

      # Fixture (spec/fixtures/wizard/<name>) copied to the target before the run.
      def existing(fixture_name)
        @existing_fixture = fixture_name
      end

      def target_name(name = nil)
        name ? (@target_name = name) : @target_name
      end

      # The first plan must fail preflight with this message; the next plan runs after.
      def expect_preflight_failure(pattern)
        @failure_pattern = pattern
      end

      def script(&block)
        @script_block = block
      end

      def dir
        File.dirname(file)
      end

      def expected_path
        File.join(dir, "expected.rb")
      end

      def work_dir(root)
        File.join(root, "tmp", "golden_wizard", name)
      end

      def target_path(root)
        File.join(work_dir(root), "spec", "system", target_name)
      end

      # --- run ---------------------------------------------------------------

      def run(root:, update: false)
        FileUtils.rm_rf(work_dir(root))
        FileUtils.mkdir_p(File.dirname(target_path(root)))
        if existing_fixture
          FileUtils.cp(File.join(root, "spec/fixtures/wizard", existing_fixture), target_path(root))
        end
        logs = []
        plans.each_with_index do |yaml, i|
          plan_path = File.join(work_dir(root), "plan#{i + 1}.yml")
          File.write(plan_path, yaml.gsub(TARGET_PLACEHOLDER, target_path(root)))
          out, status = record(root, plan_path, i)
          logs << out
          if i.zero? && failure_pattern
            raise "expected the first plan to fail preflight, but it passed:\n#{out.lines.last(30).join}" if status.success?
            raise "the first plan failed, but not with #{failure_pattern.inspect}:\n#{out.lines.last(40).join}" unless out.match?(failure_pattern)
            raise "a failed preflight must write nothing, but #{target_path(root)} changed" if target_changed_after_failure?(root)
          elsif !status.success?
            raise "wizard run failed (see #{work_dir(root)}/record#{i + 1}.log):\n#{out.lines.last(40).join}"
          end
        end
        generated = File.read(target_path(root))
        final = generated.lines.reject { |l| l.strip == "magic_test" }.join
        File.write(target_path(root), final)
        replays = REPLAYS.times.map { |i| replay(root, i) }
        offenses = rubocop(root)
        File.write(expected_path, final) if update
        expected = File.exist?(expected_path) ? File.read(expected_path) : nil
        GoldenFlow::Result.new(flow: self, generated: final, expected: expected, record_log: logs.join("\n"), replays: replays, rubocop: offenses)
      end

      private

      def target_changed_after_failure?(root)
        return File.exist?(target_path(root)) unless existing_fixture
        File.read(target_path(root)) != File.read(File.join(root, "spec/fixtures/wizard", existing_fixture))
      end

      def record(root, plan_path, index)
        env = {
          "MAGIC_TEST" => "1", "MAGIC_TEST_HEADLESS" => "1", "MAGIC_TEST_WIZARD" => "plan", "MAGIC_TEST_WIZARD_PLAN" => plan_path,
          "MAGIC_TEST_SCRIPT" => File.expand_path("golden_wizard_script.rb", __dir__),
          "MAGIC_TEST_GOLDEN_FLOW" => file, "MAGIC_TEST_GOLDEN_NAME" => name,
          "FIXTURE_APP_DB" => File.join(work_dir(root), "record#{index + 1}.sqlite3"), "RAILS_ENV" => "test"
        }
        out, status = Open3.capture2e(env, "bin/rspec", File.join(root, "lib/magic_test/wizard/entry_spec.rb"), chdir: root)
        File.write(File.join(work_dir(root), "record#{index + 1}.log"), out)
        [out, status]
      end

      def replay(root, index)
        env = {"FIXTURE_APP_DB" => File.join(work_dir(root), "replay#{index}.sqlite3"), "RAILS_ENV" => "test", "MAGIC_TEST" => nil, "MAGIC_TEST_SCRIPT" => nil, "MAGIC_TEST_WIZARD" => nil}
        out, status = Open3.capture2e(env, "bin/rspec", target_path(root), chdir: root)
        File.write(File.join(work_dir(root), "replay#{index}.log"), out)
        {ok: status.success?, output: out}
      end

      def rubocop(root)
        config = File.expand_path("../../../spec/golden/rubocop.yml", __dir__)
        out, status = Open3.capture2e({"RAILS_ENV" => "test"}, "bin/rubocop", "-c", config, "--format", "simple", target_path(root), chdir: root)
        {ok: status.success?, output: out}
      end
    end
  end
end
