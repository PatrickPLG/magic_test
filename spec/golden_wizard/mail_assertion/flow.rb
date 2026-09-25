# The reminder delivers DiscountMailer.reminder to the provider's user; the
# recorder suggests the deliveries assertion with the address as a let
# expression, and the before clears deliveries first.
MagicTest::Testing::WizardFlow.define("mail_assertion") do
  plan <<~YAML
    description: provider sends a reminder email
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
      mail_assertion: true
  YAML

  script do |h|
    h.click_on("Send påmindelse")
    answer_dialog(:accept)
    wait_for_suggestion("ActionMailer::Base.deliveries.last.to")
    accept_suggestion("ActionMailer::Base.deliveries.last.to")
    accept_suggestion("ReminderFollowUpJob.jobs.size")
    settle
  end
end
