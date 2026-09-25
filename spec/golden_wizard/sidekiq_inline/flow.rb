# Sidekiq::Testing.inline! around the steps: the reminder's follow-up job
# creates a note during the request, which the reloaded page then shows.
# Without the block the faked job never runs and the note count stays 0.
MagicTest::Testing::WizardFlow.define("sidekiq_inline") do
  plan <<~YAML
    description: provider sends a reminder and the follow-up job runs inline
    target:
      path: __TARGET__
    signed_in: provider
    models:
      - let: provider
        factory: provider
      - let: discount
        factory: discount
        traits: [active]
    start:
      route: provider_admin_discounts
      params:
        provider_id: provider
    extras:
      sidekiq_inline: true
  YAML

  script do |h|
    h.click_on("Send påmindelse")
    answer_dialog(:accept)
    h.visit("/udbydere/#{Provider.first.id}/admin/rabatter")
    set_mode(:assert, assertion_type: "css")
    h.click(".js-note-count")
    settle
  end
end
