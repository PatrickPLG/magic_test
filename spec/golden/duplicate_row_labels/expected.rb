require 'rails_helper'

RSpec.describe('Backoffice edits the second lead in a table where every row says rediger', :js, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:leads) { %w[Anders Bente Carl].map { |n| create(:lead, name: n, email: "#{n.downcase}@x.dk") } }

  before do
    sign_in_as_provider(provider)
  end

  it 'backoffice edits the second lead in a table where every row says Rediger' do
    visit(backoffice_leads_path)
    within('tr', text: 'Bente') do
      click_on(I18n.t('leads.index.edit'))
    end
    select('contacted', from: I18n.t('activerecord.attributes.lead.status'))
    fill_in(I18n.t('activerecord.attributes.lead.note'), with: 'Ringet op')
    click_on(I18n.t('helpers.submit.lead.update'))
    expect(page).to(have_content(I18n.t('leads.update.success')))
  end
end
