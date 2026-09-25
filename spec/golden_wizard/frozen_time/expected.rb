require 'rails_helper'

# guest sees this week's events on the frozen date
RSpec.describe("Guest sees this week's events on the frozen date", :js, type: :system) do
  let!(:institution) { create(:institution) }
  let!(:event) { create(:event, :published, institution: institution, name: 'Julefrokost', starts_at: '2026-10-03 14:00') }

  before do
    driven_by(:cuprite)
    travel_to(Time.zone.parse('2026-10-01 10:00'))
    page.driver.set_cookie('cookie_settings', 'necessary')
  end

  it "guest sees this week's events on the frozen date" do
    visit(today_path)
    expect(page).to(have_content('Julefrokost – 03/10-2026 14:00'))
  end
end
