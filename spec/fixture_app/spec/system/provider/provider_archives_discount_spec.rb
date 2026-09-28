require 'rails_helper'
require_relative '../../support/system_auth_helper'

RSpec.describe('Provider archives a discount', :js, type: :system) do
  let(:provider) { create(:provider, :with_cvr) }
  let!(:discount) { create(:discount, :active, provider: provider, name_da: 'Kaffe 20%') }
  let!(:archived) { create(:discount, :archived, provider: provider) }

  before do
    driven_by :cuprite
    sign_in_as_provider(provider)
  end

  it 'moves the card to the archive' do
    visit provider_admin_discounts_path(provider)
    expect(page).to have_content('Kaffe 20%')
  end
end
