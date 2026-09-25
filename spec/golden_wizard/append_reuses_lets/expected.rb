require 'rails_helper'
require_relative '../support/system_auth_helper'

RSpec.describe('Provider discounts', :js, type: :system) do
  let(:provider) { create(:provider, :with_cvr) }
  let!(:discount) { create(:discount, :active, provider: provider) }

  before do
    driven_by :cuprite
    sign_in_as_provider(provider)
  end

  it 'lists the discounts' do
    visit(provider_admin_discounts_path(provider))
    expect(page).to(have_content('Kaffe'))
  end

  context 'when the discount is archived' do
    let!(:archived) { create(:discount, :archived, provider: provider) }

    it 'hides it' do
      visit(provider_admin_discounts_path(provider))
      expect(page).to(have_no_content(archived.name_da))
    end
  end

  it 'provider renames the discount' do
    visit(provider_admin_discounts_path(provider))
    click_on(I18n.t('discounts.index.edit'))
    fill_in(I18n.t('simple_form.labels.discount.name_da'), with: 'Kaffe 25%')
    click_on(I18n.t('helpers.submit.discount.update'))
    expect(page).to(have_content(I18n.t('discounts.update.success')))
  end
end
