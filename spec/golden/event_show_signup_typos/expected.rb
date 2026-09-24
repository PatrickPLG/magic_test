require 'rails_helper'

RSpec.describe('Student signs up for an event through buttons with deliberate typos in the copy', :js, type: :system) do
  let!(:institution) { create(:institution, :with_user, allow_events: true) }
  let!(:event) { create(:event, institution: institution, name: 'Fredagsbar') }
  let!(:student) { create(:student, automatic_verified: true) }

  before do
    student.user.update!(onboarded: true)
    sign_in_as_student(student)
  end

  it 'student signs up for an event through buttons with deliberate typos in the copy' do
    visit(event_path(event))
    click_on(I18n.t('events.show.signup'))
    click_on(I18n.t('events.show.continue_to_payment'))
    expect(page).to(have_content('Kom til fredagsbar'))
    expect(page).to(have_current_path(event_path(event), ignore_query: true))
  end
end
