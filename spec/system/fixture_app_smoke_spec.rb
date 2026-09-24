require "rails_helper"

RSpec.describe("Fixture app smoke", type: :system) do
  let!(:institution) { create(:institution, :with_user, :with_specialities, allow_events: true) }
  let!(:category) { create(:category, name: "Fest") }

  before do
    sign_in_as_institution(institution)
  end

  it "boots the Studiz replica with all widgets initialised" do
    visit institution_students_path(institution)
    expect(page).to(have_content("Studerende"))
    click_on("Arrangementer")
    click_on("Opret arrangement")
    expect(page).to(have_css("#events_event_category_id_chosen"))
    expect(page).to(have_css("trix-editor[input^='trix_input_']"))
    expect(page.evaluate_script("!!document.querySelector('#events_event_starts_at').closest('.js-datetimepicker-field')._flatpickr")).to(be(true))
    fill_in("* Navn", with: "Test event")
    click_on("Arrangør")
    fill_in("Kontonummer", with: "1234567890")
    click_on("Gem arrangement")
    expect(page).to(have_content("Alle arrangementer"))
    expect(page).to(have_content("Arrangement oprettet"))
    expect(Events::Event.count).to(eq(1))
    expect(page.current_path).to(eq("/institutioner/#{institution.id}/arrangementer"))
  end
end
