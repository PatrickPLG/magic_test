require "rails_helper"
require "magic_test/wizard"
require "magic_test/wizard/tui"
require "stringio"

TuiFakeRunner = Struct.new(:catalogue)

RSpec.describe(MagicTest::Wizard::TUI) do
  def tui(answers)
    described_class.new(TuiFakeRunner.new(MagicTest::Wizard::Catalogue.current), input: StringIO.new(answers.join("\n") + "\n"), output: StringIO.new)
  end

  it "chooses by number, by exact option or by a filter that matches one option" do
    t = tui(["2", "gamma", "bet", "zz", "a", "al", ""])
    options = %w[alpha beta gamma]
    expect(t.choose("x", options)).to(eq("beta"))
    expect(t.choose("x", options)).to(eq("gamma"))
    expect(t.choose("x", options)).to(eq("beta"))
    expect(t.choose("x", options)).to(eq("alpha")) # "zz" matches nothing and "a" matches all three: both re-ask
    expect(t.choose("x", options, default: "gamma")).to(eq("gamma")) # blank takes the default
  end

  it "parses multi-selects from numbers and names and keeps the default on blank" do
    t = tui(["1, gam", "", "-"])
    options = %w[alpha beta gamma]
    expect(t.multi("x", options)).to(eq(%w[alpha gamma]))
    expect(t.multi("x", options, default: ["beta"])).to(eq(["beta"]))
    expect(t.multi("x", options, default: ["beta"])).to(eq([]))
  end

  it "answers yes/no with defaults" do
    t = tui(["", "n", "yes"])
    expect(t.yes?("x", default: true)).to(be(true))
    expect(t.yes?("x", default: true)).to(be(false))
    expect(t.yes?("x", default: false)).to(be(true))
  end

  it "collects a whole plan from typed answers" do
    answers = [
      "provider renames a discount",   # description
      "new file",                       # target
      "spec/system/provider/renames_spec.rb",
      "Provider",                       # role (filter)
      "provider",                       # let name
      "with_cvr",                       # traits
      "discount",                       # add model
      "discount",                       # let name
      "active",                         # traits
      "1",                              # count
      "provider",                       # discount.provider association
      "name_da=Kaffe 20%",              # attribute
      "",                               # no more attributes
      "",                               # no more models
      "provider_admin_discounts_path",  # start page (filter)
      "provider",                       # provider_id
      "da",                             # locale
      "",                               # flags: none
      "",                               # travel_to
      "desktop",                        # viewport
      "",                               # sidekiq inline (default no)
      "",                               # mail assertion (default no)
      ""                                # fixture files: none
    ]
    t = tui(answers)
    plan = t.collect(MagicTest::Wizard::Plan.new)
    expect(plan.description).to(eq("provider renames a discount"))
    expect(plan.target.path).to(eq("spec/system/provider/renames_spec.rb"))
    expect(plan.signed_in).to(eq("provider"))
    expect(plan.models.map(&:to_h)).to(eq([
      {"let" => "provider", "factory" => "provider", "traits" => ["with_cvr"], "count" => 1, "associations" => {}, "attributes" => {}},
      {"let" => "discount", "factory" => "discount", "traits" => ["active"], "count" => 1, "associations" => {"provider" => "provider"}, "attributes" => {"name_da" => "Kaffe 20%"}}
    ]))
    expect(plan.start.to_h).to(eq({"route" => "provider_admin_discounts", "params" => {"provider_id" => "provider"}, "locale" => "da"}))
    expect(plan.extras.viewport).to(be_nil)
    expect(MagicTest::Wizard::Validator.validate(plan, MagicTest::Wizard::Catalogue.current).errors).to(be_empty)
  end
end
