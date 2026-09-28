require 'rails_helper'

RSpec.describe('Provider archives a discount from its card', :js, type: :system) do
  let!(:provider) { create(:provider, :with_cvr) }
  let!(:discount) { create(:discount, provider: provider, name_da: 'Kaffe 20%') }
  let!(:other_discount) { create(:discount, provider: provider, name_da: 'Te 10%') }

  before do
    sign_in_as_provider(provider)
  end

  it 'provider archives a discount from its card' do
    visit(provider_admin_discounts_path(provider))
    within("#discount-card-#{discount.id}") do
      find('div.card-body').click
    end
    within('#full-view-modal') do
      click_on(I18n.t('discounts.show.archive_now'))
    end
    expect(page).to(have_content(I18n.t('discounts.show.archived_toast')))
    expect(discount.reload.archived).to(eq(true))
  end
end
