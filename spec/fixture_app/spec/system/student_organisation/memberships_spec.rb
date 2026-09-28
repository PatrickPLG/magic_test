require 'rails_helper'
require_relative '../../support/system_auth_helper'

RSpec.describe('Student organisation memberships', :js, type: :system) do
  let(:organisation) { create(:student_organisation, :with_user) }
  let!(:members) { create_list(:student_organisation_membership, 2, student_organisation: organisation) }

  before do
    driven_by :cuprite
    sign_in_as_student_organisation(organisation)
  end

  it 'lists the members' do
    visit student_organisation_student_organisation_memberships_path
    expect(page).to have_css('tr', minimum: 2)
  end
end
