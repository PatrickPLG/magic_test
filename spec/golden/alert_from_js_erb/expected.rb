require 'rails_helper'

RSpec.describe('Provider sends a reminder and the js.erb response alerts', :js, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:discount) { create(:discount, provider: provider, name_da: 'Kaffe 20%') }

  before do
    sign_in_as_provider(provider)
  end

  it 'provider sends a reminder and the js.erb response alerts' do
    visit(provider_admin_discounts_path(provider))
    accept_alert(I18n.t('discounts.index.reminder_sent')) do
      click_on(I18n.t('discounts.index.send_reminder'))
    end
    expect(page).to(have_css('span.badge.js-reminder-count', text: '1'))
  end
end
