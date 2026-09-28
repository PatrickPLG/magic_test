require 'rails_helper'
require_relative '../../support/system_auth_helper'

RSpec.describe('Institution events', :js, type: :system) do
  let(:institution) { create(:institution, :with_user, :with_specialities, allow_events: true) }
  let!(:events) { create_list(:event, 3, :published, institution: institution) }
  let!(:categories) { %w[Fest Foredrag].map { |n| create(:category, name: n) } }

  before do
    driven_by :cuprite
    sign_in_as_institution(institution)
  end

  it 'lists the events' do
    visit institution_events_path(institution)
    expect(page).to have_css('tr', count: 3)
  end

  it 'creates an event' do
    visit new_institution_event_path(institution)
    fill_in '* Navn', with: 'Fredagsbar'
    click_on 'Gem arrangement'
    expect(page).to have_content('Fredagsbar')
  end
end
