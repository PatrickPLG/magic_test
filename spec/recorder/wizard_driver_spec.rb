require "rails_helper"
require "open3"

# B1 (1.2): the wizard's entry example set no driver. Studiz registers no
# default driver (every spec calls `driven_by :cuprite` itself), so rspec-rails
# fell back to selenium and magic_sign_in crashed with NoMethodError set_cookie.
RSpec.describe("B1: the wizard example drives Cuprite itself", :recorder, type: :system) do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:work) { File.join(root, "tmp", "wizard_driver") }

  before { studiz_driven_by }

  it "runs the entry spec under the Studiz-mirror configuration (no global driver)" do
    FileUtils.rm_rf(work)
    target = File.join(work, "spec/system/provider/mirror_spec.rb")
    FileUtils.mkdir_p(File.dirname(target))
    plan = File.join(work, "plan.yml")
    File.write(plan, <<~YAML)
      description: provider sees the discounts
      target:
        path: #{target}
      signed_in: provider
      models:
        - let: provider
          factory: provider
          traits: [with_cvr]
      start:
        route: provider_admin_discounts
        params:
          provider_id: provider
    YAML
    env = {
      "FIXTURE_STUDIZ_MIRROR" => "1", "MAGIC_TEST" => "1", "MAGIC_TEST_HEADLESS" => "1",
      "MAGIC_TEST_WIZARD" => "plan", "MAGIC_TEST_WIZARD_PLAN" => plan,
      "MAGIC_TEST_SCRIPT" => File.join(root, "spec/fixtures/wizard/ui/record_script.rb"),
      "FIXTURE_APP_DB" => File.join(work, "mirror.sqlite3"), "RAILS_ENV" => "test"
    }
    out, status = Open3.capture2e(env, "bin/rspec", File.join(root, "lib/magic_test/wizard/entry_spec.rb"), chdir: root)
    File.write(File.join(work, "mirror.log"), out)
    expect(out).not_to(include("selenium"), out.lines.last(30).join)
    expect(status.success?).to(be(true), out.lines.last(40).join)
    expect(out).to(include("recording starts now", "session finished"))
    expect(File.read(target)).to(include("driven_by(:cuprite)", "magic_sign_in(provider.user)"))
  end

  it "magic_sign_in names the driver it got and the line to add when it is not Cuprite" do
    driven_by(:rack_test)
    provider = create(:provider, :with_cvr)
    expect { magic_sign_in(provider.user) }.to(raise_error(
      MagicTest::Helpers::HelperError,
      /magic_sign_in needs Cuprite \(got Capybara::RackTest::Driver\); add `driven_by :cuprite`/
    ))
  end
end
