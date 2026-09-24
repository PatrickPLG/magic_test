require 'rails_helper'

RSpec.describe('Provider edits a discount', :js, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:discount) { create(:discount, provider: provider, name_da: 'Kaffe 20%', status: 'draft') }
  let!(:categories) { %w[Fest Foredrag Sport Kultur Musik].map { |n| create(:category, name: n) } }

  before do
    sign_in_as_provider(provider)
  end

  it 'provider edits a discount' do
    visit(provider_admin_discounts_path(provider))
    click_on(I18n.t('discounts.index.edit'))
    fill_in(I18n.t('simple_form.labels.discount.name_da'), with: 'Kaffe 25%')
    magic_chosen_select('Aktiv', from: I18n.t('activerecord.attributes.discount.status'))
    magic_chosen_select('Sport', from: I18n.t('activerecord.attributes.discount.categories'))
    magic_chosen_select('Fest', from: I18n.t('activerecord.attributes.discount.categories'))
    magic_chosen_unselect('Sport', from: I18n.t('activerecord.attributes.discount.categories'))
    magic_attach_image('Vælg billede', Rails.root.join('spec/fixtures/files/cover.png'))
    click_on(I18n.t('helpers.submit.discount.update'))
    expect(page).to(have_content(I18n.t('discounts.update.success')))
    expect(discount.reload.name_da).to(eq('Kaffe 25%'))
  end
end
