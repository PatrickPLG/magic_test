require 'rails_helper'

RSpec.describe('Provider opens a discount card and renames it', :js, type: :system) do
  let!(:provider) { create(:provider, :with_cvr) }
  let!(:other_discount) { create(:discount, provider: provider, name_da: "Rabat #{SecureRandom.hex(3)}") }
  let!(:discount) { create(:discount, provider: provider, name_da: "Rabat #{SecureRandom.hex(3)}") }

  before do
    sign_in_as_provider(provider)
  end

  it 'provider opens a discount card and renames it' do
    visit(provider_admin_discounts_path(provider))
    find("#discount-card-#{discount.id}").click
    within('#full-view-modal') do
      click_on(discount.name_da)
    end
    fill_in(I18n.t('simple_form.labels.discount.name_da'), with: 'Kaffe 25%')
    click_on(I18n.t('helpers.submit.discount.update'))
    expect(page).to(have_content(I18n.t('discounts.update.success')))
    expect(discount.reload.name_da).to(eq('Kaffe 25%'))
  end
end
