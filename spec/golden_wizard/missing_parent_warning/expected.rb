require 'rails_helper'

# guest reads a published event
RSpec.describe('Guest reads a published event', :js, type: :system) do
  let!(:event) { create(:event, :published, name: 'Julefrokost') }

  before do
    driven_by(:cuprite)
    page.driver.set_cookie('cookie_settings', 'necessary')
  end

  it 'guest reads a published event' do
    visit(event_path(event))
    expect(page).to(have_content('Julefrokost'))
  end
end
