require "rails_helper"
require "magic_test/testing/golden_flow"

# Record -> generate -> replay for every flow under spec/golden/*/flow.rb.
# Each flow is recorded once in a subprocess (MAGIC_TEST=1, headless Chrome,
# scripted human), the generated spec is replayed 3 times on a fresh database,
# checked with the Studiz rubocop rules, checked for forbidden patterns and
# compared with the committed snapshot (UPDATE_GOLDEN=1 rewrites snapshots).
RSpec.describe("Golden flows", :golden, :recorder) do
  root = File.expand_path("../..", __dir__)
  flows = MagicTest::Testing::GoldenFlow.load_all(__dir__)
  only = ENV["GOLDEN"].to_s.split(",").reject(&:empty?)
  flows = flows.select { |f| only.include?(f.name) } if only.any?

  flows.each do |flow|
    it "#{flow.name}: records, replays #{MagicTest::Testing::GoldenFlow::REPLAYS}/#{MagicTest::Testing::GoldenFlow::REPLAYS} and matches the snapshot" do
      result = flow.run(root: root, update: ENV["UPDATE_GOLDEN"].present?)
      code = result.generated

      aggregate_failures do
        expect(code).not_to(match(/\bsleep\b/), "generated code must not sleep")
        expect(code).not_to(match(%r{:xpath|/html/|/HTML\[}), "generated code must not use absolute XPath")
        expect(code).not_to(match(/[#_\[-]\d{10,}/), "generated code must not contain timestamp ids")
        expect(code).not_to(match(/trix_input_\d+/), "generated code must not use trix_input_N")
        expect(code).not_to(match(/\.find\(\d+\)/), "generated code must not contain literal DB ids")
        expect(code).not_to(match(/['"]#[\w-]*?[-_]\d+['"]/), "generated code must not contain ids embedding record ids")
        expect(code).not_to(match(/magic_test: REVIEW/), "generated code must not need review:\n#{code}")
        expect(result.rubocop[:ok]).to(be(true), "rubocop offenses:\n#{result.rubocop[:output]}")
        result.replays.each_with_index do |r, i|
          expect(r[:ok]).to(be(true), "replay #{i + 1} failed:\n#{r[:output].lines.last(60).join}")
        end
        expect(result.matches_expected?).to(be(true), "generated spec differs from #{flow.expected_path}:\n--- expected\n#{result.expected}\n--- generated\n#{code}")
      end
    end
  end
end
