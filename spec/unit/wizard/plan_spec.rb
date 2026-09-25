require "rails_helper"
require "magic_test/wizard"

RSpec.describe(MagicTest::Wizard::Plan) do
  let(:yaml) do
    <<~YAML
      description: provider edits a discount
      target:
        path: spec/system/provider/edits_discount_spec.rb
      signed_in: provider
      models:
        - let: provider
          factory: provider
          traits: [with_cvr]
        - let: discount
          factory: discount
          traits: [active]
          associations: { provider: provider }
          attributes: { name_da: "Kaffe 20%" }
      start:
        route: provider_admin_discounts
        params: { provider_id: provider }
        locale: da
      extras:
        flags:
          - name: beta_dashboard
            actor: provider
        travel_to: "2026-12-24 10:00"
        viewport: mobile
        sidekiq_inline: true
    YAML
  end

  it "round-trips through YAML" do
    plan = described_class.from_yaml(yaml)
    expect(plan.description).to(eq("provider edits a discount"))
    expect(plan.signed_in_model.factory).to(eq("provider"))
    expect(plan.model("discount").associations).to(eq({"provider" => "provider"}))
    expect(plan.start.params).to(eq({"provider_id" => "provider"}))
    expect(plan.extras.viewport_size).to(eq([390, 844]))
    expect(plan.extras.cookie_consent).to(be(true))
    again = described_class.from_yaml(plan.to_yaml)
    expect(again.to_h).to(eq(plan.to_h))
    expect(plan.dup.to_h).to(eq(plan.to_h))
  end

  it "treats a missing signed_in as guest and defaults the locale" do
    plan = described_class.from_h("description" => "x", "target" => {"path" => "spec/system/x_spec.rb"}, "start" => {"route" => "root"})
    expect(plan.guest?).to(be(true))
    expect(plan.start.locale).to(eq("da"))
    expect(plan.extras.flags).to(eq([]))
  end
end
