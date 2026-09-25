require "rails_helper"
require "magic_test/wizard"

RSpec.describe(MagicTest::Wizard::Codegen) do
  let(:catalogue) { MagicTest::Wizard::Catalogue.current }

  def plan(h)
    MagicTest::Wizard::Plan.from_h(h).tap { |p| MagicTest::Wizard::Validator.validate(p, catalogue) }
  end

  def fixture(name)
    dir = Pathname(File.expand_path("../../../tmp/wizard_spec_fixtures", __dir__)) # outside spec/, so RSpec never loads the copies
    FileUtils.mkdir_p(dir)
    path = dir.join(name)
    FileUtils.cp(File.expand_path("../../fixtures/wizard/#{name}.txt", __dir__), path)
    path.to_s
  end

  let(:base) do
    {"description" => "provider edits a discount", "target" => {"path" => "spec/system/provider/edits_discount_spec.rb"}, "signed_in" => "provider",
     "models" => [{"let" => "discount", "factory" => "discount", "traits" => ["active"], "attributes" => {"name_da" => "Kaffe 20%"}}, {"let" => "provider", "factory" => "provider", "traits" => ["with_cvr"]}],
     "start" => {"route" => "provider_admin_discounts", "params" => {"provider_id" => "provider"}}}
  end

  it "writes a new file in Studiz house style with parents first and magic_test last" do
    sk = described_class.build(plan(base), catalogue)
    expect(sk.mode).to(eq(:new_file))
    expect(sk.source).to(eq(<<~RUBY))
      require 'rails_helper'

      # provider edits a discount
      RSpec.describe('Provider edits a discount', :js, type: :system) do
        let!(:provider) { create(:provider, :with_cvr) }
        let!(:discount) { create(:discount, :active, provider: provider, name_da: 'Kaffe 20%') }

        before do
          driven_by(:cuprite)
          magic_sign_in(provider.user)
        end

        it 'provider edits a discount' do
          visit(provider_admin_discounts_path(provider))
          magic_test
        end
      end
    RUBY
    expect(sk.user_expression).to(eq("provider.user"))
  end

  it "renders extras, guests, locales, counts, none and the Institution user rule" do
    h = base.merge("signed_in" => "institution", "models" => [
      {"let" => "institution", "factory" => "institution", "traits" => ["with_user"]},
      {"let" => "events", "factory" => "event", "count" => 3, "associations" => {"institution" => "institution", "category" => "none"}}
    ], "start" => {"route" => "institution_events", "params" => {"institution_id" => "institution"}, "locale" => "en"},
      "extras" => {"flags" => [{"name" => "beta_dashboard", "actor" => "institution"}, {"name" => "new_navigation"}], "travel_to" => "2026-12-24 10:00", "viewport" => "mobile", "sidekiq_inline" => true, "mail_assertion" => true})
    sk = described_class.build(plan(h), catalogue)
    expect(sk.lets).to(eq([
      "let!(:institution) { create(:institution, :with_user) }",
      "let!(:events) { create_list(:event, 3, institution: institution, category: nil) }"
    ]))
    expect(sk.before_lines).to(eq([
      "driven_by(:cuprite)",
      "Flipper.enable_actor(:beta_dashboard, institution.employees.find_by(employee_type: InstitutionEnum::EmployeeType[:leader])&.user)",
      "Flipper.enable(:new_navigation)",
      "travel_to(Time.zone.parse('2026-12-24 10:00'))",
      "page.driver.resize(390, 844)",
      "ActionMailer::Base.deliveries.clear",
      "magic_sign_in(institution.employees.find_by(employee_type: InstitutionEnum::EmployeeType[:leader])&.user)"
    ]))
    expect(sk.it_lines).to(eq(["Sidekiq::Testing.inline! do", "  visit(institution_events_en_path(institution))", "  magic_test", "end"]))

    guest = plan(base.merge("signed_in" => nil, "models" => [], "start" => {"route" => "terms"}))
    sk2 = described_class.build(guest, catalogue)
    expect(sk2.before_lines).to(eq(["driven_by(:cuprite)", "page.driver.set_cookie('cookie_settings', 'necessary')"]))
    expect(sk2.it_lines.first).to(eq("visit(terms_path)"))
  end

  it "appends a bare `it` when the existing block already has the lets and the sign-in" do
    file = MagicTest::Wizard::SpecFile.parse(fixture("provider_discounts_spec.rb"))
    p = plan(base.merge("target" => {"path" => file.path, "block" => ["Provider discounts"]}, "models" => [
      {"let" => "provider", "factory" => "provider", "traits" => ["with_cvr"]}, {"let" => "discount", "factory" => "discount", "traits" => ["active"]}
    ]))
    sk = described_class.build(p, catalogue, spec_file: file)
    expect(sk.mode).to(eq(:append_it))
    expect(sk.reused.keys).to(eq(%w[provider discount]))
    expect(sk.body_lines).to(eq(["it 'provider edits a discount' do", "  visit(provider_admin_discounts_path(provider))", "  magic_test", "end"]))
    expect(sk.source.lines[25..29].join).to(eq("\n  it 'provider edits a discount' do\n    visit(provider_admin_discounts_path(provider))\n    magic_test\n  end\n"))
    RubyVM::InstructionSequence.compile(sk.source)
  end

  it "renames a colliding let from its trait and opens a context for new setup" do
    file = MagicTest::Wizard::SpecFile.parse(fixture("provider_discounts_spec.rb"))
    p = plan(base.merge("target" => {"path" => file.path, "block" => ["Provider discounts"]}, "models" => [
      {"let" => "provider", "factory" => "provider", "traits" => ["with_cvr"]}, {"let" => "discount", "factory" => "discount", "traits" => ["archived"]}
    ]))
    sk = described_class.build(p, catalogue, spec_file: file)
    expect(sk.mode).to(eq(:new_context))
    expect(sk.renames).to(eq({"discount" => "archived_discount"}))
    expect(sk.lets).to(eq(["let!(:archived_discount) { create(:discount, :archived, provider: provider) }"]))
    expect(sk.before_lines).to(eq(["driven_by(:cuprite)"])) # sign-in already covered by sign_in_as_provider(provider)
    expect(sk.context_description).to(eq("with archived discount"))
    expect(sk.body_lines.first).to(eq("context 'with archived discount' do"))
    RubyVM::InstructionSequence.compile(sk.source)
  end

  it "opens a context with its own sign-in when a different role is signed in" do
    file = MagicTest::Wizard::SpecFile.parse(fixture("student_profile_spec.rb"))
    p = plan(base.merge("target" => {"path" => file.path}, "models" => [{"let" => "provider", "factory" => "provider"}]))
    sk = described_class.build(p, catalogue, spec_file: file)
    expect(sk.mode).to(eq(:new_context))
    expect(sk.context_description).to(eq("when signed in as a provider"))
    expect(sk.before_lines).to(eq(["driven_by(:cuprite)", "magic_sign_in(provider.user)"]))
    expect(sk.source).to(include("  context 'when signed in as a provider' do\n    let!(:provider) { create(:provider) }\n\n    before do\n      driven_by(:cuprite)\n      magic_sign_in(provider.user)\n    end\n\n    it 'provider edits a discount' do\n      visit(provider_admin_discounts_path(provider))\n      magic_test\n    end\n  end\nend\n"))
  end
end
