MagicTest::Testing::GoldenFlow.define("nested_fields_twice") do
  description "institution adds two ticket types with client-side nested fields"
  setup <<~RUBY
    let!(:institution) { create(:institution, :with_user, allow_events: true) }

    before do
      sign_in_as_institution(institution)
    end
  RUBY
  start "visit(new_institution_event_path(institution))"

  script do |h|
    h.click("#events_event_name").type("Julefrokost")
    h.click_on("Billetter")
    h.click_on("Tilføj billettype")
    h.click("#ticket-types .ticket-type-fields:nth-of-type(1) input[name*='[name]']").type("Standard")
    h.click("#ticket-types .ticket-type-fields:nth-of-type(1) input[name*='[price]']").type("50")
    h.click_on("Tilføj billettype")
    h.click("#ticket-types .ticket-type-fields:nth-of-type(2) input[name*='[name]']").type("VIP")
    h.click("#ticket-types .ticket-type-fields:nth-of-type(2) input[name*='[price]']").type("150")
    h.click_on("Gem arrangement")
    wait_for_suggestion("Arrangement oprettet")
    accept_suggestion("Arrangement oprettet")
    accept_suggestion("Events::TicketType.count")
    settle
  end
end
