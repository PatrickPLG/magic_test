require 'rails_helper'

# student changes the first name from the starter
RSpec.describe('Student changes the first name from the starter', :js, type: :system) do
  let!(:student) { create(:student, :verified, :onboarded) }

  before do
    driven_by(:cuprite)
    magic_sign_in(student.user)
  end

  it 'student changes the first name from the starter' do
    visit(edit_profile_path)
    fill_in(I18n.t('activerecord.attributes.student.first_name'), with: 'Frederikke')
    click_on(I18n.t('helpers.submit.student.update'))
    expect(student.reload.first_name).to(eq('Frederikke'))
  end
end
