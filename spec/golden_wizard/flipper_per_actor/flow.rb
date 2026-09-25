# A Flipper flag enabled for the signed-in student only; /beta answers 404
# without it, which preflight would report.
MagicTest::Testing::WizardFlow.define("flipper_per_actor") do
  plan <<~YAML
    description: student with the beta flag opens the beta dashboard
    target:
      path: __TARGET__
    signed_in: student
    models:
      - let: student
        factory: student
        traits: [verified, onboarded]
    start:
      route: beta
    extras:
      flags:
        - name: beta_dashboard
          actor: student
  YAML

  script do |h|
    h.click_on("Tilbage til forsiden")
    accept_suggestion("have_current_path(root_path)")
    settle
  end
end
