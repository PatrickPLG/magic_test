# Mobile viewport: the bottom navigation only exists below 500px, so the
# generated spec resizes the window in its before and the recording used
# the same size.
MagicTest::Testing::WizardFlow.define("mobile_viewport") do
  plan <<~YAML
    description: student opens the profile from the mobile navigation
    target:
      path: __TARGET__
    signed_in: student
    models:
      - let: student
        factory: student
        traits: [verified, onboarded]
    start:
      route: root
    extras:
      viewport: mobile
  YAML

  script do |h|
    h.click_on("Profil")
    accept_suggestion("have_current_path(edit_profile_path)")
    settle
  end
end
