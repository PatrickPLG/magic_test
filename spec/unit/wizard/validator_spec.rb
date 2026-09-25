require "rails_helper"
require "magic_test/wizard"

RSpec.describe(MagicTest::Wizard::Validator) do
  let(:catalogue) { MagicTest::Wizard::Catalogue.current }

  def plan(overrides = {})
    base = {
      "description" => "provider edits a discount",
      "target" => {"path" => "spec/system/provider/edits_discount_spec.rb"},
      "signed_in" => "provider",
      "models" => [{"let" => "provider", "factory" => "provider"}, {"let" => "discount", "factory" => "discount", "traits" => ["active"]}],
      "start" => {"route" => "provider_admin_discounts", "params" => {"provider_id" => "provider"}}
    }
    MagicTest::Wizard::Plan.from_h(base.merge(overrides.transform_keys(&:to_s)))
  end

  def messages(validator)
    validator.issues.map { |i| "#{i.severity}: #{i.field}: #{i.message}" }
  end

  it "accepts a complete plan and auto-wires the one matching let" do
    v = described_class.validate(plan, catalogue)
    expect(v.errors).to(be_empty, messages(v).join("\n"))
    expect(v.plan.model("discount").associations).to(eq({"provider" => "provider"}))
  end

  it "auto-wires polymorphic associations from the one other let and orders parents first" do
    p = plan("models" => [{"let" => "note", "factory" => "note"}, {"let" => "discount", "factory" => "discount"}], "signed_in" => nil, "start" => {"route" => "root"})
    v = described_class.validate(p, catalogue)
    expect(v.errors).to(be_empty, messages(v).join("\n"))
    expect(p.model("note").associations["notable"]).to(eq("discount"))
    expect(v.ordered_models.map(&:let)).to(eq(%w[discount note]))

    p2 = plan("models" => [{"let" => "note", "factory" => "note"}, {"let" => "discount", "factory" => "discount"}, {"let" => "provider", "factory" => "provider"}])
    v2 = described_class.validate(p2, catalogue)
    expect(p2.model("note").associations).not_to(have_key("notable"))
    ambiguous = v2.warnings.find { |i| i.field == "models[0].associations.notable" }
    expect(ambiguous.message).to(include("Several lets could be notable: discount, provider"))
    expect(ambiguous.data[:candidates]).to(eq(%w[discount provider]))
    expect(v2.ordered_models.map(&:let)).to(eq(%w[note provider discount]).or(eq(%w[provider discount note])))
  end

  it "reports a missing parent as a warning with a one-click fix, never adding it silently" do
    p = plan("models" => [{"let" => "discount", "factory" => "discount"}], "signed_in" => nil, "start" => {"route" => "root"})
    v = described_class.validate(p, catalogue)
    issue = v.warnings.find { |i| i.field == "models[0].associations.provider" }
    expect(issue.message).to(include("Missing parent"))
    expect(issue.data[:add_model]).to(eq({"let" => "provider", "factory" => "provider"}))
    expect(p.model("discount").associations).not_to(have_key("provider"))
    expect(p.models.map(&:let)).to(eq(["discount"]))
  end

  it "rejects `none` on a NOT NULL, non-optional association and allows it on an optional one" do
    p = plan("models" => [{"let" => "provider", "factory" => "provider"}, {"let" => "discount", "factory" => "discount", "associations" => {"provider" => "none"}}])
    v = described_class.validate(p, catalogue)
    expect(messages(v)).to(include(match(/error: models\[1\].associations.provider: provider cannot be none/)))
    p2 = plan("models" => [{"let" => "institution", "factory" => "institution"}, {"let" => "event", "factory" => "event", "associations" => {"category" => "none", "institution" => "institution"}}], "signed_in" => nil, "start" => {"route" => "root"})
    v2 = described_class.validate(p2, catalogue)
    expect(v2.errors).to(be_empty, messages(v2).join("\n"))
    expect(v2.warnings.map(&:message)).to(include("category will be nil."))
  end

  it "rejects wiring to a let of the wrong class and to an unknown let" do
    p = plan("models" => [{"let" => "student", "factory" => "student"}, {"let" => "discount", "factory" => "discount", "associations" => {"provider" => "student"}}], "signed_in" => "student", "start" => {"route" => "root"})
    v = described_class.validate(p, catalogue)
    expect(messages(v)).to(include(match(/provider expects a Provider, but "student" is a Student/)))
    p2 = plan("models" => [{"let" => "provider", "factory" => "provider"}, {"let" => "discount", "factory" => "discount", "associations" => {"provider" => "ghost"}}])
    expect(messages(described_class.validate(p2, catalogue))).to(include(match(/points at "ghost", which is not a let/)))
  end

  it "detects cycles and duplicate let names" do
    p = plan("models" => [{"let" => "a", "factory" => "note", "associations" => {"notable" => "b"}}, {"let" => "b", "factory" => "note", "associations" => {"notable" => "a"}}])
    v = described_class.validate(p, catalogue)
    expect(messages(v)).to(include(match(/Circular associations: a -> b -> a/)))
    p2 = plan("models" => [{"let" => "provider", "factory" => "provider"}, {"let" => "provider", "factory" => "discount"}])
    expect(messages(described_class.validate(p2, catalogue))).to(include(match(/Two models are called "provider"/)))
  end

  it "validates factories, traits, attributes and enum values with suggestions" do
    p = plan("models" => [{"let" => "provider", "factory" => "provider"}, {"let" => "lead", "factory" => "lead", "traits" => ["hot"], "attributes" => {"priority" => "urgent", "nope" => 1}}])
    v = described_class.validate(p, catalogue)
    trait = v.errors.find { |i| i.field == "models[1].traits" }
    expect(trait.message).to(eq("Factory :lead has no trait :hot."))
    expect(trait.fix).to(include(":contacted", ":high_priority"))
    expect(v.errors.find { |i| i.field == "models[1].attributes.priority" }.fix).to(eq("one of: low, normal, high"))
    expect(v.errors.find { |i| i.field == "models[1].attributes.nope" }.message).to(include("no attribute \"nope\""))
    p2 = plan("models" => [{"let" => "x", "factory" => "discoun"}])
    expect(described_class.validate(p2, catalogue).errors.first.fix).to(include(":discount"))
  end

  it "validates the signed-in role and the start page" do
    p = plan("signed_in" => "discount")
    expect(messages(described_class.validate(p, catalogue))).to(include(match(/Discount cannot sign in/)))
    p2 = plan("start" => {"route" => "provider_admin_discounts", "params" => {}})
    expect(messages(described_class.validate(p2, catalogue))).to(include(match(/provider_admin_discounts_path needs :provider_id/)))
    p3 = plan("start" => {"route" => "institution_students", "params" => {"institution_id" => "provider"}})
    v3 = described_class.validate(p3, catalogue)
    expect(v3.errors).to(be_empty)
    expect(v3.warnings.map(&:message)).to(include(match(/institution_students is a institution page; the signed-in role is Provider/)))
    p4 = plan("start" => {"route" => "nowhere"})
    expect(messages(described_class.validate(p4, catalogue))).to(include(match(/No route called nowhere/)))
  end

  it "validates extras" do
    p = plan("extras" => {"travel_to" => "yesterday-ish", "viewport" => "watch", "flags" => [{"name" => "beta_dashboard", "actor" => "ghost"}, {"name" => "unknown_flag"}], "fixture_files" => ["nope.png"]})
    v = described_class.validate(p, catalogue)
    m = messages(v)
    expect(m).to(include(match(/is not a date\/time/), match(/Unknown viewport watch/), match(/actor "ghost" is not a let/), match(/No fixture file nope.png/)))
    expect(m).to(include(match(/warning: extras.flags: No code checks Flipper flag :unknown_flag/)))
  end
end
