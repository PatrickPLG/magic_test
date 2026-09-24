require 'rails_helper'

RSpec.describe('Institution adds two ticket types with client-side nested fields', :js, type: :system) do
  let!(:institution) { create(:institution, :with_user, allow_events: true) }

  before do
    sign_in_as_institution(institution)
  end

  it 'institution adds two ticket types with client-side nested fields' do
    visit(new_institution_event_path(institution))
    fill_in(I18n.t('activerecord.attributes.events/event.name'), with: 'Julefrokost')
    click_on(I18n.t('events.form.tickets'))
    click_on(I18n.t('events.form.add_ticket_type'))
    fill_in(I18n.t('activerecord.attributes.events/ticket_type.name'), with: 'Standard')
    fill_in(I18n.t('activerecord.attributes.events/ticket_type.price'), with: '050')
    click_on(I18n.t('events.form.add_ticket_type'))
    within(all('div.ticket-type-fields', minimum: 2)[1]) do
      fill_in(I18n.t('activerecord.attributes.events/ticket_type.name'), with: 'VIP')
      fill_in(I18n.t('activerecord.attributes.events/ticket_type.price'), with: '0150')
    end
    click_on(I18n.t('helpers.submit.events_event.create'))
    expect(page).to(have_content(I18n.t('events.create.success')))
    expect(Events::TicketType.count).to(eq(2))
  end
end
