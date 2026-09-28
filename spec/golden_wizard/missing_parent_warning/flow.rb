# The event's institution is not a let: the event factory builds it, so the
# validator offers a hint (with the one-click fix) instead of adding a let
# silently or warning (B6). The written spec has exactly the lets the plan named.
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
  expect_output(/hints:.*The :event factory builds event\.institution \(a Institution\) that no let refers to\..*also name this record: add let!\(:institution\) \{ create\(:institution\) \}/m)

  script do |h|
    h.select_text("h1")
    h.press("X", :alt, :shift)
    settle
  end
end
