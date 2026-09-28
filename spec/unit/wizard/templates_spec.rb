require "rails_helper"
require "magic_test/wizard"

# 1.2 §5: "Save as template" and `bin/magic new --template <name>`.
RSpec.describe(MagicTest::Wizard::Templates) do
  let(:root) { Pathname(File.expand_path("../../../tmp/wizard_templates_spec", __dir__)) }
  let(:plan) do
    MagicTest::Wizard::Plan.from_h("description" => "provider edits a discount", "target" => {"path" => "spec/system/provider/x_spec.rb"}, "signed_in" => "provider",
      "models" => [{"let" => "provider", "factory" => "provider", "traits" => ["with_cvr"]}], "start" => {"route" => "provider_admin_discounts", "params" => {"provider_id" => "provider"}})
  end

  before { FileUtils.rm_rf(root) }

  it "saves a plan under spec/magic_test/templates/<slug>.yml and lists and loads it back" do
    path = described_class.save(plan, "Provider: active discount", root)
    expect(path).to(eq(root.join("spec/magic_test/templates/provider_active_discount.yml").to_s))
    list = described_class.list(root)
    expect(list.map { |t| t.slice("name", "slug") }).to(eq([{"name" => "Provider: active discount", "slug" => "provider_active_discount"}]))
    loaded = described_class.load("provider_active_discount", root)
    expect(loaded.to_h).to(eq(plan.to_h))
    expect(described_class.load("Provider: active discount", root).signed_in).to(eq("provider"))
  end

  it "rejects an empty name and explains an unknown template" do
    expect { described_class.save(plan, "!!!", root) }.to(raise_error(MagicTest::Wizard::Error, /needs a name/))
    described_class.save(plan, "one", root)
    expect { described_class.load("two", root) }.to(raise_error(MagicTest::Wizard::Error, /no template called "two".*have: one/))
  end
end
