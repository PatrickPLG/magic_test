require 'rails_helper'

# student with the beta flag opens the beta dashboard
RSpec.describe('Student with the beta flag opens the beta dashboard', :js, type: :system) do
  let!(:student) { create(:student, :verified, :onboarded) }

  before do
    driven_by(:cuprite)
    Flipper.enable_actor(:beta_dashboard, student.user)
    magic_sign_in(student.user)
  end

  it 'student with the beta flag opens the beta dashboard' do
    visit(beta_path)
    click_on(I18n.t('beta.back'))
    expect(page).to(have_current_path(root_path))
  end
end
