require 'rails_helper'

RSpec.describe('Student searches inside the same-origin preview iframe', :js, type: :system) do
  let!(:student) { create(:student, automatic_verified: true) }

  before do
    student.user.update!(onboarded: true)
    sign_in_as_student(student)
  end

  it 'student searches inside the same-origin preview iframe' do
    visit(preview_path)
    within_frame('preview') do
      fill_in('Søg i rammen', with: 'kaffe')
      click_on('Søg')
    end
    within_frame('preview') do
      expect(page).to(have_content('Du søgte efter: kaffe'))
    end
  end
end
