require 'rails_helper'

RSpec.describe('Provider opens the invoice in a new window and marks it paid', :js, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:invoice) { create(:invoice, provider: provider, number: 'F-2026-1') }

  before do
    sign_in_as_provider(provider)
  end

  it 'provider opens the invoice in a new window and marks it paid' do
    visit(provider_admin_discounts_path(provider))
    new_window = window_opened_by do
      click_on(I18n.t('discounts.index.see_invoice'))
    end
    visit(invoice_path(invoice))
    check('Betalt')
    click_on('Udskriv')
  end
end
