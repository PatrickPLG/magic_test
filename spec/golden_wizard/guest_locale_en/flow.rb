# Not signed in, English locale: the start page is the `_en_path` helper and
# the cookie consent is set by hand (magic_sign_in normally does it).
MagicTest::Testing::WizardFlow.define("guest_locale_en") do
  plan <<~YAML
    description: guest reads the terms in English
    target:
      path: __TARGET__
    models: []
    start:
      route: terms
      locale: en
  YAML

  script do |h|
    h.select_text("h1")
    h.press("X", :alt, :shift)
    h.click_on("Tilbage")
    accept_suggestion("have_current_path(root_en_path)")
    settle
  end
end
