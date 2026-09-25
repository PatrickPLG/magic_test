require 'rails_helper'

# student opens the profile from the mobile navigation
RSpec.describe('Student opens the profile from the mobile navigation', :js, type: :system) do
  let!(:student) { create(:student, :verified, :onboarded) }

  before do
    driven_by(:cuprite)
    page.driver.resize(390, 844)
    magic_sign_in(student.user)
  end

  it 'student opens the profile from the mobile navigation' do
    visit(root_path)
    click_on(I18n.t('nav.mobile_profile'))
    expect(page).to(have_current_path(edit_profile_path))
  end
end
