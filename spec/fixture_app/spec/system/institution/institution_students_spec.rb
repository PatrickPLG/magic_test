require 'rails_helper'
require_relative '../../support/system_auth_helper'

RSpec.describe('Institution students', :js, type: :system) do
  let(:institution) { create(:institution, :with_user, :with_specialities) }

  before do
    driven_by :cuprite
    sign_in_as_institution(institution)
  end

  it 'shows the students page' do
    visit institution_students_path(institution)
    expect(page).to have_content('Studerende')
  end
end
