require 'rails_helper'

RSpec.describe('Student types a birthday into the flatpickr field with the custom year select', :js, type: :system) do
  let!(:student) { create(:student, automatic_verified: true) }

  before do
    student.user.update!(onboarded: true)
    sign_in_as_student(student)
  end

  it 'student types a birthday into the flatpickr field with the custom year select' do
    visit(edit_profile_path)
    magic_set_date(I18n.t('activerecord.attributes.student.birthday'), '14/02-2001')
    click_on(I18n.t('helpers.submit.student.update'))
    expect(page).to(have_content(I18n.t('profile.update.success')))
    expect(student.reload.birthday).to(eq(Date.new(2001, 2, 14)))
  end
end
