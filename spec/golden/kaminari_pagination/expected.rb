require 'rails_helper'

RSpec.describe('Backoffice pages to the second page of leads and edits one', :js, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:leads) { %w[Anders Bente Carl Dorte Erik].map { |n| create(:lead, name: n, email: "#{n.downcase}@x.dk") } }

  before do
    sign_in_as_provider(provider)
  end

  it 'backoffice pages to the second page of leads and edits one' do
    visit(backoffice_leads_path)
    click_on('2')
    within('tr', text: 'Erik') do
      click_on(I18n.t('leads.index.edit'))
    end
    fill_in(I18n.t('activerecord.attributes.lead.name'), with: 'Erik Hansen')
    click_on(I18n.t('helpers.submit.lead.update'))
    expect(page).to(have_content(I18n.t('leads.update.success')))
  end
end
