# A provider with a CVR number and one active discount; new file; the
# recorder then renames the discount. The plan is what `bin/magic new` would
# have collected in the browser or the terminal.
MagicTest::Testing::WizardFlow.define("provider_new_file") do
  plan <<~YAML
    description: provider renames a discount
    target:
      path: __TARGET__
    signed_in: provider
    models:
      - let: provider
        factory: provider
        traits: [with_cvr]
      - let: discount
        factory: discount
        traits: [active]
        attributes:
          name_da: Kaffe 20%
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
    accept_suggestion("discount.reload.name_da")
    settle
  end
end
