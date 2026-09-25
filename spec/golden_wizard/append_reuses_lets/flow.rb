# Appends an `it` to a Studiz-style file whose describe already has the
# provider, the discount and sign_in_as_provider(provider): the lets are
# reused, no context is opened, the example lands at the end of the block.
MagicTest::Testing::WizardFlow.define("append_reuses_lets") do
  existing "provider_discounts_spec.rb.txt"
  plan <<~YAML
    description: provider renames the discount
    target:
      path: __TARGET__
      block: ["Provider discounts"]
    signed_in: provider
    models:
      - let: provider
        factory: provider
        traits: [with_cvr]
      - let: discount
        factory: discount
        traits: [active]
    start:
      route: provider_admin_discounts
      params:
        provider_id: provider
  YAML

  script do |h|
    h.click_on("Rediger")
    h.click("#discount_name_da").select_all.type("Kaffe 25%")
    h.click_on("Gem")
    wait_for_suggestion("Rabatten er gemt")
    accept_suggestion("Rabatten er gemt")
    settle
  end
end
