require 'rails_helper'

RSpec.describe('Provider sets the status with the search-less chosen select and uses the description', :js, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:discount) { create(:discount, provider: provider, name_da: 'Kaffe 20%', status: 'draft') }

  before do
    sign_in_as_provider(provider)
  end

  it 'provider sets the status with the search-less Chosen select and uses the description' do
    visit(edit_provider_admin_discount_path(provider, discount))
    magic_chosen_select('Inaktiv', from: I18n.t('activerecord.attributes.discount.status'))
    fill_in(I18n.t('activerecord.attributes.discount.description'), with: 'Gælder ikke i weekenden.')
    fill_in(I18n.t('activerecord.attributes.discount.name_en'), with: 'Coffee 20%')
    click_on(I18n.t('helpers.submit.discount.update'))
    expect(page).to(have_content(I18n.t('discounts.update.success')))
    expect(discount.reload.status).to(eq('inactive'))
  end
end
