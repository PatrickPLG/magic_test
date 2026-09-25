# The event's institution is not a let: the validator warns (with the
# one-click fix) instead of adding a let silently, and the factory builds the
# parent. The written spec has exactly the lets the plan named.
MagicTest::Testing::WizardFlow.define("missing_parent_warning") do
  plan <<~YAML
    description: guest reads a published event
    target:
      path: __TARGET__
    models:
      - let: event
        factory: event
        traits: [published]
        attributes:
          name: Julefrokost
    start:
      route: event
      params:
        id: event
  YAML
  expect_output(/Missing parent: no let of class Institution for institution.*add let!\(:institution\) \{ create\(:institution\) \}/)

  script do |h|
    h.select_text("h1")
    h.press("X", :alt, :shift)
    settle
  end
end
