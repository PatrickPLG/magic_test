require 'rails_helper'

RSpec.describe('Provider archives a discount through the ajax-modal confirmation', :js, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:discount) { create(:discount, provider: provider, name_da: 'Kaffe 20%') }

  before do
    sign_in_as_provider(provider)
  end

  it 'provider archives a discount through the ajax-modal confirmation' do
    visit(provider_admin_discounts_path(provider))
    click_on(I18n.t('discounts.index.archive'))
    within('#ajax-modal') do
      click_on(I18n.t('discounts.archive.confirm'))
    end
    expect(page).to(have_content(I18n.t('discounts.confirm_archive.success')))
  end
end
