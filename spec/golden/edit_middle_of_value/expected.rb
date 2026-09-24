require 'rails_helper'

RSpec.describe('Student edits the middle of a typed value before saving', :js, type: :system) do
  let!(:student) { create(:student, automatic_verified: true, first_name: 'Mette') }

  before do
    student.user.update!(onboarded: true)
    sign_in_as_student(student)
  end

  it 'student edits the middle of a typed value before saving' do
    visit(edit_profile_path)
    fill_in(I18n.t('activerecord.attributes.student.first_name'), with: 'Anne- Maria')
    click_on(I18n.t('helpers.submit.student.update'))
    expect(page).to(have_content(I18n.t('profile.update.success')))
    expect(student.reload.first_name).to(eq('Anne- Maria'))
  end
end
