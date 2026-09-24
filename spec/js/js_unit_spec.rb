require "rails_helper"

# Runs each spec/js/*.test.js file inside the real Chromium against the
# fixture app's JS test page, with the recorder bundle loaded by the
# middleware. One RSpec example per file; failures list the failing JS tests.
RSpec.describe("Recorder JavaScript unit tests", :recorder, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:discount) { create(:discount, provider: provider, name_da: "Kaffe 20%") }
  let!(:categories) { %w[Fest Foredrag Sport Kultur Musik].map { |n| create(:category, name: n) } }

  Dir[File.expand_path("*.test.js", __dir__)].sort.each do |file|
    it "passes #{File.basename(file)}" do
      sign_in_as_provider(provider)
      visit "/js-test-page?discount_id=#{discount.id}"
      recorder.start
      page.execute_script(File.read(File.expand_path("harness.js", __dir__)))
      page.execute_script(File.read(file))
      results = page.evaluate_script("window.__mt.results()")
      failures = results.reject { |r| r["ok"] }
      expect(results).not_to(be_empty)
      expect(failures).to(be_empty, lambda {
        failures.map { |f| "  ✗ #{f["name"]}\n      #{f["error"]}" }.join("\n")
      })
    end
  end
end
