require 'rails_helper'

# provider sends a reminder email
RSpec.describe('Provider sends a reminder email', :js, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:discount) { create(:discount, :active, provider: provider) }

  before do
    driven_by(:cuprite)
    ActionMailer::Base.deliveries.clear
    magic_sign_in(provider.user)
  end

  it 'provider sends a reminder email' do
    visit(provider_admin_discounts_path(provider))
    accept_alert(I18n.t('discounts.index.reminder_sent')) do
      click_on(I18n.t('discounts.index.send_reminder'))
    end
    expect(ActionMailer::Base.deliveries.last.to).to(include(provider.user.email))
    expect(ReminderFollowUpJob.jobs.size).to(eq(1))
  end
end
