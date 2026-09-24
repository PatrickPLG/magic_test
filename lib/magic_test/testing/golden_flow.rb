# frozen_string_literal: true

require "fileutils"
require "open3"
require "shellwords"

module MagicTest
  module Testing
    # A golden flow: a scripted recording session plus the expected generated
    # spec. `GoldenFlow.define` is evaluated in two processes: the runner
    # (generates the recording spec, replays, compares) and the recording
    # subprocess (runs `script` against the live session).
    class GoldenFlow
      REPLAYS = 3

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

      attr_reader :name, :script_block, :file

      def initialize(name, file:)
        @name = name
        @description = name.tr("_", " ")
        @setup = ""
        @start = []
        @file = File.expand_path(file)
      end

      # --- definition DSL -------------------------------------------------------

      def description(text = nil)
        text ? (@description = text) : @description
      end

      # `let!`/`before` lines placed inside the describe block.
      def setup(code = nil)
        code ? (@setup = code) : @setup
      end

      # Lines executed before `magic_test` (usually one `visit`).
      def start(*lines)
        lines.empty? ? @start : @start.concat(lines)
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

      # --- generated files -----------------------------------------------------

      def spec_source(with_magic_test: true)
        setup_lines = setup.to_s.strip.lines.map { |l| "  #{l.rstrip}".rstrip }
        body = start.map { |l| "    #{l}" }
        body << "    magic_test" if with_magic_test
        [
          "require 'rails_helper'",
          "",
          "RSpec.describe(#{RubyLiteral.string(description.capitalize)}, :js, type: :system) do",
          *setup_lines,
          (setup_lines.empty? ? nil : ""),
          "  it #{RubyLiteral.string(description)} do",
          *body,
          "  end",
          "end",
          ""
        ].compact.join("\n")
      end

      def work_dir(root)
        File.join(root, "tmp", "golden", name)
      end

      def spec_path(root)
        File.join(work_dir(root), "#{name}_spec.rb")
      end

      # Runs the whole cycle. Returns a Result.
      def run(root:, update: false)
        FileUtils.rm_rf(work_dir(root))
        FileUtils.mkdir_p(work_dir(root))
        File.write(spec_path(root), spec_source)
        record_log = record(root)
        generated = File.read(spec_path(root))
        final = strip_magic_test(generated)
        File.write(spec_path(root), final)
        replays = REPLAYS.times.map { |i| replay(root, i) }
        offenses = rubocop(root)
        if update
          File.write(expected_path, final)
        end
        expected = File.exist?(expected_path) ? File.read(expected_path) : nil
        Result.new(flow: self, generated: final, expected: expected, record_log: record_log, replays: replays, rubocop: offenses)
      end

      Result = Struct.new(:flow, :generated, :expected, :record_log, :replays, :rubocop) do
        def matches_expected?
          expected && normalise(expected) == normalise(generated)
        end

        def normalise(text)
          text.lines.map(&:rstrip).join("\n").strip
        end

        def replays_green?
          replays.all? { |r| r[:ok] }
        end

        def rubocop_clean?
          rubocop[:ok]
        end

        def generated_steps
          generated.lines.map(&:strip).reject { |l| l.empty? }
        end
      end

      private

      def strip_magic_test(source)
        source.lines.reject { |l| l.strip == "magic_test" }.join
      end

      def record(root)
        env = {
          "MAGIC_TEST" => "1", "MAGIC_TEST_HEADLESS" => "1",
          "MAGIC_TEST_SCRIPT" => File.expand_path("golden_script.rb", __dir__),
          "MAGIC_TEST_GOLDEN_FLOW" => file, "MAGIC_TEST_GOLDEN_NAME" => name,
          "FIXTURE_APP_DB" => File.join(work_dir(root), "record.sqlite3"),
          "RAILS_ENV" => "test"
        }
        out, status = Open3.capture2e(env, "bin/rspec", spec_path(root), chdir: root)
        File.write(File.join(work_dir(root), "record.log"), out)
        raise "recording session failed (see #{work_dir(root)}/record.log):\n#{out.lines.last(40).join}" unless status.success?
        out
      end

      def replay(root, index)
        env = {"FIXTURE_APP_DB" => File.join(work_dir(root), "replay#{index}.sqlite3"), "RAILS_ENV" => "test", "MAGIC_TEST" => nil, "MAGIC_TEST_SCRIPT" => nil}
        out, status = Open3.capture2e(env, "bin/rspec", spec_path(root), chdir: root)
        File.write(File.join(work_dir(root), "replay#{index}.log"), out)
        {ok: status.success?, output: out}
      end

      def rubocop(root)
        config = File.expand_path("../../../spec/golden/rubocop.yml", __dir__)
        out, status = Open3.capture2e({"RAILS_ENV" => "test"}, "bin/rubocop", "-c", config, "--format", "simple", spec_path(root), chdir: root)
        {ok: status.success?, output: out}
      end
    end
  end
end
