require 'rails_helper'

# institution opens its events
RSpec.describe('Institution opens its events', :js, type: :system) do
  let!(:institution) { create(:institution, :allow_events, :with_user) }

  before do
    driven_by(:cuprite)
    magic_sign_in(institution.employees.find_by(employee_type: InstitutionEnum::EmployeeType[:leader])&.user)
  end

  it 'institution opens its events' do
    visit(institution_students_path(institution))
    click_on(I18n.t('nav.events'))
    expect(page).to(have_current_path(institution_events_path(institution)))
  end
end
