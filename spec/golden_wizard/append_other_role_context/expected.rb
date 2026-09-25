require 'rails_helper'
require_relative '../support/system_auth_helper'

RSpec.describe('Student profile', :js, type: :system) do
  let!(:student) { create(:student, automatic_verified: true) }

  before do
    driven_by(:cuprite)
    sign_in_as_student(student)
  end

  it 'shows the profile' do
    visit(edit_profile_path)
    expect(page).to(have_content('Fornavn'))
  end

  context 'when signed in as a provider' do
    let!(:provider) { create(:provider) }
    let!(:discount) { create(:discount, :active, provider: provider, name_da: 'Kaffe 20%') }

    before do
      driven_by(:cuprite)
      magic_sign_in(provider.user)
    end

    it 'provider sees the discounts' do
      visit(provider_admin_discounts_path(provider))
      expect(page).to(have_content('Kaffe 20%'))
    end
  end
end
