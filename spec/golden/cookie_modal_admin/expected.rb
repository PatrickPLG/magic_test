require 'rails_helper'

RSpec.describe('Provider without the cookie setting accepts only necessary cookies', :js, type: :system) do
  let!(:provider) { create(:provider) }

  before do
    provider.user.ensure_authentication_token
    sign_in(provider.user)
    page.driver.set_cookie('auth_token', provider.user.authentication_token)
  end

  it 'provider without the cookie setting accepts only necessary cookies' do
    visit(provider_admin_discounts_path(provider))
    within('#cookie-modal') do
      click_on(I18n.t('cookies.necessary'))
    end
    click_on(I18n.t('discounts.index.new'))
    fill_in(I18n.t('simple_form.labels.discount.name_da'), with: 'Te 10%')
    click_on(I18n.t('helpers.submit.discount.create'))
    expect(page).to(have_content(I18n.t('discounts.create.success')))
  end
end
