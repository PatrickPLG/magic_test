require 'rails_helper'

RSpec.describe('Student pastes into a profile field and saves', :js, type: :system) do
  let!(:student) { create(:student, automatic_verified: true, first_name: 'Mette', last_name: 'Frederiksen') }

  before do
    student.user.update!(onboarded: true)
    sign_in_as_student(student)
  end

  it 'student pastes into a profile field and saves' do
    visit(edit_profile_path)
    fill_in(I18n.t('activerecord.attributes.student.last_name'), with: 'Nielsen-Holm')
    fill_in(I18n.t('simple_form.labels.student.bio'), with: "Jeg læser jura på 3. semester.\nElsker kaffe.")
    click_on(I18n.t('helpers.submit.student.update'))
    expect(page).to(have_content(I18n.t('profile.update.success')))
    expect(student.reload.last_name).to(eq('Nielsen-Holm'))
  end
end
