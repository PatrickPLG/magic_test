# travel_to in the before: the /today page lists the events of the next 7
# days relative to Time.current, so the frozen date decides what is shown.
MagicTest::Testing::WizardFlow.define("frozen_time") do
  plan <<~YAML
    description: guest sees this week's events on the frozen date
    target:
      path: __TARGET__
    models:
      - let: institution
        factory: institution
      - let: event
        factory: event
        traits: [published]
        attributes:
          name: Julefrokost
          starts_at: "2026-10-03 14:00"
    start:
      route: today
    extras:
      travel_to: "2026-10-01 10:00"
  YAML

  script do |h|
    h.select_text("#upcoming-events li")
    h.press("X", :alt, :shift)
    settle
  end
end
