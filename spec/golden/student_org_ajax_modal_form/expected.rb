require 'rails_helper'

RSpec.describe('Student organisation adds a member through the ajax modal form', :js, type: :system) do
  let!(:organisation) { create(:student_organisation) }

  before do
    sign_in_as_student_organisation(organisation)
  end

  it 'student organisation adds a member through the ajax modal form' do
    visit(student_organisation_student_organisation_memberships_path)
    click_on(I18n.t('memberships.index.add'))
    within('#ajax-modal') do
      fill_in(I18n.t('activerecord.attributes.student_organisation_membership.name'), with: 'Ida Nielsen')
      fill_in(I18n.t('activerecord.attributes.student_organisation_membership.email'), with: 'ida@studiz.dk')
      select('Bestyrelse', from: I18n.t('activerecord.attributes.student_organisation_membership.membership_type'))
      click_on(I18n.t('helpers.submit.student_organisation_membership.create'))
    end
    expect(page).to(have_content(I18n.t('memberships.create.success')))
    expect(page).to(have_no_css('#ajax-modal.show'))
    expect(StudentOrganisationMembership.count).to(eq(1))
  end
end
