require 'rails_helper'

RSpec.describe('Provider deletes a discount after a data-confirm dialog', :js, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:discount) { create(:discount, provider: provider, name_da: 'Kaffe 20%') }

  before do
    sign_in_as_provider(provider)
  end

  it 'provider deletes a discount after a data-confirm dialog' do
    visit(provider_admin_discounts_path(provider))
    accept_confirm(I18n.t('discounts.index.confirm_delete')) do
      click_on(I18n.t('discounts.index.delete'))
    end
    expect(page).to(have_content(I18n.t('discounts.destroy.success')))
    expect(Discount.count).to(eq(0))
  end
end
