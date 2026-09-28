require 'rails_helper'
require_relative '../../support/system_auth_helper'

RSpec.describe('Provider invoices', :js, type: :system) do
  let(:provider) { create(:provider, :with_cvr, :with_english_company_description) }
  let!(:invoice) { create(:invoice, provider: provider) }

  before do
    driven_by :cuprite
    sign_in_as_provider(provider)
  end

  it 'opens the invoice' do
    visit provider_admin_discounts_path(provider)
    click_on 'Se faktura'
    expect(page).to have_content(invoice.number)
  end
end
