require 'rails_helper'

RSpec.describe('Student types a url, reads the terms and asserts the heading', :js, type: :system) do
  let!(:student) { create(:student, automatic_verified: true) }

  before do
    sign_in_as_student(student)
    student.user.update!(onboarded: true)
  end

  it 'student types a URL, reads the terms and asserts the heading' do
    visit(root_path)
    visit(terms_path)
    expect(page).to(have_content("Studiz' vilkår"))
    click_on('Tilbage')
    expect(page).to(have_current_path(root_path))
  end
end
