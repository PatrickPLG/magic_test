require 'rails_helper'

RSpec.describe('Institution asserts fields, a select, a button and a row count with assert mode', :js, type: :system) do
  let!(:institution) { create(:institution, :with_user, allow_events: true) }
  let!(:events) { %w[Fredagsbar Foredrag].map { |n| create(:event, institution: institution, name: n) } }

  before do
    sign_in_as_institution(institution)
  end

  it 'institution asserts fields, a select, a button and a row count with assert mode' do
    visit(institution_events_path(institution))
    within('#events-table') do
      expect(page).to(have_css('tr', count: 2))
    end
    click_on(I18n.t('events.index.new'))
    fill_in(I18n.t('activerecord.attributes.events/event.name'), with: 'Nyt navn')
    expect(page).to(have_field(I18n.t('activerecord.attributes.events/event.name'), with: 'Nyt navn'))
    expect(page).to(have_button(I18n.t('helpers.submit.events_event.create'), disabled: false))
    expect(page).to(have_unchecked_field(I18n.t('activerecord.attributes.events/event.published')))
    expect(page).to(have_content(I18n.t('events.index.new')))
  end
end
