require "rails_helper"
require "magic_test/testing/wizard_flow"

# Wizard golden flows: plan.yml -> preflight -> skeleton -> scripted recording
# -> Save -> replay 3/3 on fresh databases -> rubocop -> snapshot.
RSpec.describe("Golden wizard flows", :golden_wizard, :recorder) do
  root = File.expand_path("../..", __dir__)
  flows = MagicTest::Testing::WizardFlow.load_all(__dir__)
  only = ENV["GOLDEN"].to_s.split(",").reject(&:empty?)
  flows = flows.select { |f| only.include?(f.name) } if only.any?

  flows.each do |flow|
    it "#{flow.name}: preflights, writes the skeleton, records, replays 3/3 and matches the snapshot" do
      result = flow.run(root: root, update: ENV["UPDATE_GOLDEN"].present?)
      code = result.generated

      aggregate_failures do
        expect(code).not_to(match(/\bsleep\b/), "generated code must not sleep")
        expect(code).not_to(match(%r{:xpath|/html/}), "generated code must not use absolute XPath")
        expect(code).not_to(match(/\.find\(\d+\)/), "generated code must not contain literal DB ids")
        expect(code).not_to(match(/magic_test: REVIEW/), "generated code must not need review:\n#{code}")
        expect(result.rubocop[:ok]).to(be(true), "rubocop offenses:\n#{result.rubocop[:output]}")
        result.replays.each_with_index do |r, i|
          expect(r[:ok]).to(be(true), "replay #{i + 1} failed:\n#{r[:output].lines.last(60).join}")
        end
        expect(result.matches_expected?).to(be(true), "written spec differs from #{flow.expected_path}:\n--- expected\n#{result.expected}\n--- generated\n#{code}")
      end
    end
  end
end
