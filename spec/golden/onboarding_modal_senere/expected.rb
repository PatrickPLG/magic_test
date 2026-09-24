require 'rails_helper'

RSpec.describe('New student dismisses the onboarding modal with senere and reads the terms', :js, type: :system) do
  let!(:student) { create(:student, automatic_verified: true) }

  before do
    sign_in_as_student(student)
  end

  it 'new student dismisses the onboarding modal with Senere and reads the terms' do
    visit(root_path)
    within('#onboarding-modal') do
      click_on(I18n.t('onboarding.later'))
    end
    click_on("Læs Studiz' vilkår")
    expect(page).to(have_current_path(terms_path))
  end
end
