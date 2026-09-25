require 'rails_helper'

# provider sends a reminder and the follow-up job runs inline
RSpec.describe('Provider sends a reminder and the follow-up job runs inline', :js, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:discount) { create(:discount, :active, provider: provider) }

  before do
    driven_by(:cuprite)
    magic_sign_in(provider.user)
  end

  it 'provider sends a reminder and the follow-up job runs inline' do
    Sidekiq::Testing.inline! do
      visit(provider_admin_discounts_path(provider))
      accept_alert(I18n.t('discounts.index.reminder_sent')) do
        click_on(I18n.t('discounts.index.send_reminder'))
      end
      expect(page).to(have_css('span[title="Noter"]', text: '0'))
    end
  end
end
