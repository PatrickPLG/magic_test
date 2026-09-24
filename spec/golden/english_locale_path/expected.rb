require 'rails_helper'

RSpec.describe('Institution uses the english locale path', :js, type: :system) do
  let!(:institution) { create(:institution, :with_user, allow_events: true) }

  before do
    sign_in_as_institution(institution)
  end

  it 'institution uses the English locale path' do
    visit(institution_students_path(institution))
    visit(institution_events_en_path(institution))
    click_on(I18n.t('events.index.new', locale: :en))
    fill_in(I18n.t('activerecord.attributes.events/event.name', locale: :en), with: 'English event')
    click_on(I18n.t('helpers.submit.events_event.create', locale: :en))
    expect(page).to(have_content(I18n.t('events.create.success', locale: :en)))
    expect(page).to(have_current_path(institution_events_en_path(institution)))
  end
end
