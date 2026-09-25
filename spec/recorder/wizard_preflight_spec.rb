require "rails_helper"
require "magic_test/wizard/runner"

# One example per preflight failure class (brief §6.4): each names the stage,
# the reason and a concrete fix, and nothing is written.
RSpec.describe("Wizard preflight failures", :recorder, type: :system) do
  let(:root) { Rails.root.join("tmp/wizard_preflight") }
  let(:runner) { MagicTest::Wizard::Runner.new(self) }

  before { FileUtils.rm_rf(root) }

  def plan(h)
    base = {"description" => "x", "target" => {"path" => root.join("spec/system/x_spec.rb").to_s}}
    MagicTest::Wizard::Plan.from_h(base.merge(h))
  end

  def preflight(p)
    validator = runner.validate(p)
    raise "plan invalid: #{validator.errors.map(&:message)}" unless validator.valid?
    runner.preflight(runner.codegen_for(p))
  end

  it "reports a role without a user and names the missing trait" do
    result = preflight(plan("signed_in" => "institution", "models" => [{"let" => "institution", "factory" => "institution"}],
      "start" => {"route" => "institution_students", "params" => {"institution_id" => "institution"}}))
    expect(result.ok).to(be(false))
    f = result.failures.first
    expect(f.stage).to(eq("sign_in"))
    expect(f.message).to(include("Institution has no user to sign in with"))
    expect(f.fix).to(eq("add trait :with_user to let!(:institution) (the institution needs a leader employee with a user)"))
    expect(File.exist?(root.join("spec/system/x_spec.rb"))).to(be(false))
  end

  it "reports an invalid record with the validation errors and a fix" do
    result = preflight(plan("signed_in" => "company", "models" => [{"let" => "company", "factory" => "company", "attributes" => {"cvr" => ""}}],
      "start" => {"route" => "company_dashboard"}))
    expect(result.ok).to(be(false))
    f = result.failures.first
    expect(f.stage).to(eq("lets"))
    expect(f.message).to(include("let!(:company) { create(:company, cvr: '') }", "ActiveRecord::RecordInvalid"))
    expect(f.fix).to(eq("set the attribute in the overrides or pick a trait that fills it"))
  end

  it "reports a 403 when the signed-in role does not own the record" do
    result = preflight(plan("signed_in" => "provider", "models" => [{"let" => "provider", "factory" => "provider"}, {"let" => "other_provider", "factory" => "provider"}],
      "start" => {"route" => "provider_admin_discounts", "params" => {"provider_id" => "other_provider"}}))
    expect(result.ok).to(be(false))
    f = result.failures.first
    expect(f.stage).to(eq("visit"))
    expect(f.message).to(match(%r{/udbydere/\d+/admin/rabatter answered 403 Forbidden}))
    expect(f.fix).to(include("the signed-in Provider does not own that record"))
    expect(result.status).to(eq(403))
  end

  it "reports a route param that points at the wrong let" do
    result = preflight(plan("signed_in" => "provider", "models" => [{"let" => "provider", "factory" => "provider"}],
      "start" => {"route" => "institution_students", "params" => {"institution_id" => "provider"}}))
    expect(result.ok).to(be(false))
    f = result.failures.first
    expect(f.stage).to(eq("visit"))
    expect(f.message).to(match(/answered (403 Forbidden|404 Not Found|500)/))
    expect(f.fix).to(eq("the route param :institution_id points at provider (a Provider); it probably needs a let of class Institution"))
  end

  it "reports a guest redirected to the login page" do
    result = preflight(plan("models" => [{"let" => "provider", "factory" => "provider"}],
      "start" => {"route" => "provider_admin_discounts", "params" => {"provider_id" => "provider"}}))
    expect(result.ok).to(be(false))
    f = result.failures.first
    expect(f.stage).to(eq("visit"))
    expect(f.message).to(include("redirected to the login page (/users/sign_in)"))
    expect(f.fix).to(eq("the page needs a signed-in user: pick a role"))
  end

  it "passes, keeps the records, signs in and lands on the page with a screenshot" do
    result = preflight(plan("signed_in" => "provider", "models" => [{"let" => "provider", "factory" => "provider"}, {"let" => "discount", "factory" => "discount"}],
      "start" => {"route" => "provider_admin_discounts", "params" => {"provider_id" => "provider"}}))
    expect(result.ok).to(be(true), result.summary)
    expect(result.status).to(eq(200))
    expect(result.records.map { |r| r[:class] }).to(eq(%w[Provider Discount]))
    expect(result.user).to(start_with("provider.user (User#"))
    expect(result.screenshot).to(be_a(String))
    expect(page.current_path).to(eq("/udbydere/#{provider.id}/admin/rabatter")) # the let is now callable here
    expect(Discount.count).to(eq(1))
  end

  it "reports a validation error for an unknown trait before preflight" do
    p = plan("signed_in" => "provider", "models" => [{"let" => "provider", "factory" => "provider", "traits" => ["with_gold"]}], "start" => {"route" => "root"})
    v = runner.validate(p)
    expect(v.errors.first.message).to(eq("Factory :provider has no trait :with_gold."))
    expect(v.errors.first.fix).to(eq("known traits: :with_cvr, :with_user"))
  end
end
