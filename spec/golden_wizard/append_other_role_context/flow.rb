# The existing file signs in a student; the new example needs a provider, so
# it gets its own context with lets, a before (driver + magic_sign_in) and
# the example.
MagicTest::Testing::WizardFlow.define("append_other_role_context") do
  existing "student_profile_spec.rb.txt"
  plan <<~YAML
    description: provider sees the discounts
    target:
      path: __TARGET__
    signed_in: provider
    models:
      - let: provider
        factory: provider
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
    h.select_text("h5.card-title")
    h.press("X", :alt, :shift)
    settle
  end
end
