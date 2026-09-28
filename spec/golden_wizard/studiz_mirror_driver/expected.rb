require 'rails_helper'

# provider renames a discount
RSpec.describe('Provider renames a discount', :js, type: :system) do
  let!(:provider) { create(:provider, :with_cvr) }
  let!(:discount) { create(:discount, :active, provider: provider, name_da: 'Kaffe 20%') }

  before do
    driven_by(:cuprite)
    magic_sign_in(provider.user)
  end

  it 'provider renames a discount' do
    visit(provider_admin_discounts_path(provider))
    click_on(I18n.t('discounts.index.edit'))
    fill_in(I18n.t('simple_form.labels.discount.name_da'), with: 'Kaffe 25%')
    click_on(I18n.t('helpers.submit.discount.update'))
    expect(page).to(have_content(I18n.t('discounts.update.success')))
    expect(discount.reload.name_da).to(eq('Kaffe 25%'))
  end
end
