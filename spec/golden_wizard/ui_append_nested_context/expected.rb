require 'rails_helper'
require_relative '../support/system_auth_helper'

RSpec.describe('Provider Discounts Page', :js, type: :system) do
  let(:provider) { create(:provider, :with_cvr) }

  before do
    driven_by :cuprite
    sign_in_as_provider(provider)
  end

  describe 'index page' do
    let!(:discount) { create(:discount, :active, provider: provider) }

    context 'Visuals' do
      it 'shows the discount' do
        visit(provider_admin_discounts_path(provider))
        expect(page).to(have_content(discount.name_da))
      end
    end

    context 'Form operations' do
      it 'opens the edit form' do
        visit(provider_admin_discounts_path(provider))
        click_on('Rediger')
        expect(page).to(have_css('#discount_name_da'))
      end
    end
  end

  describe 'edit page' do
    let!(:discount) { create(:discount, :active, provider: provider, name_da: 'Kaffe 20%') }

    context 'Visuals' do
      it 'shows the name' do
        visit(edit_provider_admin_discount_path(provider, discount))
        expect(page).to(have_field('discount_name_da', with: 'Kaffe 20%'))
      end

      it 'provider renames the discount on the edit page' do
        visit(edit_provider_admin_discount_path(provider, discount))
        fill_in(I18n.t('simple_form.labels.discount.name_da'), with: 'Kaffe 25%')
        click_on(I18n.t('helpers.submit.discount.update'))
        expect(page).to(have_content(I18n.t('discounts.update.success')))
        expect(discount.reload.name_da).to(eq('Kaffe 25%'))
      end
    end

    context 'Form operations', :slow do
      it 'saves a new name' do
        visit(edit_provider_admin_discount_path(provider, discount))
        fill_in('discount_name_da', with: 'Kaffe 25%')
        click_on('Gem')
        expect(page).to(have_content('Rabatten er gemt'))
      end
    end

    context 'Form operations' do
      it 'stays on the edit page' do
        visit(edit_provider_admin_discount_path(provider, discount))
        expect(page).to(have_current_path(edit_provider_admin_discount_path(provider, discount)))
      end
    end
  end
end
