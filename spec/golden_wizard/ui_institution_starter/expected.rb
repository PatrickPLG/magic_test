require 'rails_helper'

# institution leader creates an event from the starter
RSpec.describe('Institution leader creates an event from the starter', :js, type: :system) do
  let!(:institution) { create(:institution, :with_user, :with_specialities, :allow_events) }
  let!(:category) { create(:category, name: 'Fest') }

  before do
    driven_by(:cuprite)
    magic_sign_in(institution.employees.find_by(employee_type: InstitutionEnum::EmployeeType[:leader])&.user)
  end

  it 'institution leader creates an event from the starter' do
    visit(institution_events_path(institution))
    click_on(I18n.t('events.index.new'))
    fill_in(I18n.t('activerecord.attributes.events/event.name'), with: 'Fredagsbar')
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
