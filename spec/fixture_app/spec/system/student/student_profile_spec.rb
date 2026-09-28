require 'rails_helper'
require_relative '../../support/system_auth_helper'

RSpec.describe('Student profile', :js, type: :system) do
  let(:student) { create(:student, :verified, :onboarded) }

  before do
    driven_by :cuprite
    sign_in_as_student(student)
  end

  it 'edits the profile' do
    visit edit_profile_path
    fill_in 'Fornavn', with: 'Mette'
    click_on 'Gem'
    expect(student.reload.first_name).to eq('Mette')
  end
end
