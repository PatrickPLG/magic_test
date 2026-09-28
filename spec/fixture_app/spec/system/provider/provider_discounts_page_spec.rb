require 'rails_helper'
require_relative '../../support/system_auth_helper'

# Studiz-style spec the wizard learns from (never run by this gem's suite).
RSpec.describe('Provider Discounts Page', :js, type: :system) do
  let(:provider) { create(:provider, :with_cvr) }
  let!(:discount) { create(:discount, :active, provider: provider) }

  before do
    driven_by :cuprite
    sign_in_as_provider(provider)
  end

  describe 'index page' do
    context 'Visuals' do
      it 'shows the discount card' do
        visit provider_admin_discounts_path(provider)
        expect(page).to have_content(discount.name_da)
      end
    end

    context 'Form operations' do
      it 'opens the edit form' do
        visit provider_admin_discounts_path(provider)
        click_on 'Rediger'
        expect(page).to have_css('#discount_name_da')
      end
    end
  end
end
