require 'rails_helper'

# admin marks a lead as contacted
RSpec.describe('Admin marks a lead as contacted', :js, type: :system) do
  let!(:admin) { create(:admin) }
  let!(:lead) { create(:lead, name: 'Lead A') }

  before do
    driven_by(:cuprite)
    magic_sign_in(admin.user)
  end

  it 'admin marks a lead as contacted' do
    visit(backoffice_leads_path)
    click_on(I18n.t('leads.index.edit'))
    select('contacted', from: I18n.t('activerecord.attributes.lead.status'))
    click_on(I18n.t('helpers.submit.lead.update'))
    expect(lead.reload.status).to(eq('contacted'))
  end
end
