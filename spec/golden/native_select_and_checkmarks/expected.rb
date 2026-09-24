require 'rails_helper'

RSpec.describe('Student picks a country, a gender and the newsletter with custom checkmarks', :js, type: :system) do
  let!(:student) { create(:student, automatic_verified: true) }

  before do
    student.user.update!(onboarded: true)
    sign_in_as_student(student)
  end

  it 'student picks a country, a gender and the newsletter with custom checkmarks' do
    visit(edit_profile_path)
    select('Sverige', from: I18n.t('activerecord.attributes.student.country'))
    choose(I18n.t('profile.edit.female'), allow_label_click: true)
    check(I18n.t('activerecord.attributes.student.newsletter'), allow_label_click: true)
    click_on(I18n.t('helpers.submit.student.update'))
    expect(page).to(have_content(I18n.t('profile.update.success')))
    expect(student.reload.country).to(eq('SE'))
  end
end
