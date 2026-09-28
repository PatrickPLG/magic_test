# B1 (1.2): Studiz registers no default driver and calls `driven_by :cuprite`
# in each spec, so the wizard example has to set the driver itself. The
# provider_new_file plan, run under FIXTURE_STUDIZ_MIRROR=1 (no global driver,
# no driven_by hook); the replays run under it too.
MagicTest::Testing::WizardFlow.define("studiz_mirror_driver") do
  env "FIXTURE_STUDIZ_MIRROR" => "1"

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
