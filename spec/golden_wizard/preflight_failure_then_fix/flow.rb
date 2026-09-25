# First attempt: an institution without :with_user has no leader employee, so
# there is no user to sign in with. Preflight names the trait; nothing is
# written. Second attempt with the trait passes.
MagicTest::Testing::WizardFlow.define("preflight_failure_then_fix") do
  plan <<~YAML
    description: institution opens its events
    target:
      path: __TARGET__
    signed_in: institution
    models:
      - let: institution
        factory: institution
        traits: [allow_events]
    start:
      route: institution_students
      params:
        institution_id: institution
  YAML
  expect_preflight_failure(/preflight failed at sign_in: .*Institution has no user to sign in with.*add trait :with_user to let!\(:institution\)/)
  then_plan <<~YAML
    description: institution opens its events
    target:
      path: __TARGET__
    signed_in: institution
    models:
      - let: institution
        factory: institution
        traits: [allow_events, with_user]
    start:
      route: institution_students
      params:
        institution_id: institution
  YAML

  script do |h|
    h.click_on("Arrangementer")
    accept_suggestion("have_current_path(institution_events_path(institution))")
    settle
  end
end
