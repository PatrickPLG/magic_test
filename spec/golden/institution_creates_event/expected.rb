require 'rails_helper'

RSpec.describe('Institution creates an event', :js, type: :system) do
  let!(:institution) { create(:institution, :with_user, :with_specialities, allow_events: true) }
  let!(:category) { create(:category, name: 'Fest') }
  let!(:other_categories) { %w[Foredrag Sport Kultur Musik].map { |n| create(:category, name: n) } }

  before do
    sign_in_as_institution(institution)
  end

  it 'institution creates an event' do
    visit(institution_students_path(institution))
    click_on(I18n.t('nav.events'))
    click_on(I18n.t('events.index.new'))
    fill_in(I18n.t('activerecord.attributes.events/event.name'), with: "Fredagsbar i Studiz' gård")
    magic_fill_trix(I18n.t('activerecord.attributes.events/event.description'), with: 'Kom til fredagsbar')
    magic_chosen_select('Fest', from: I18n.t('activerecord.attributes.events/event.category'))
    magic_set_date(I18n.t('activerecord.attributes.events/event.starts_at'), '24/09-2026 14:00')
    check(I18n.t('activerecord.attributes.events/event.terms_accepted'))
    click_on(I18n.t('events.form.organiser'))
    fill_in(I18n.t('activerecord.attributes.events/event.account_number'), with: '1234567890')
    click_on(I18n.t('helpers.submit.events_event.create'))
    expect(page).to(have_content(I18n.t('events.create.success')))
    expect(Events::Event.count).to(eq(1))
  end
end
