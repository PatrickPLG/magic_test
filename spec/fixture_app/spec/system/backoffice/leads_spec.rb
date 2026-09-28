require 'rails_helper'
require_relative '../../support/system_auth_helper'

RSpec.describe('Backoffice leads', :js, type: :system) do
  let(:admin) { create(:admin) }
  let!(:leads) { create_list(:lead, 3, :contacted) }

  before do
    driven_by :cuprite
    sign_in admin.user
  end

  it 'lists the leads' do
    visit backoffice_leads_path
    expect(page).to have_css('tr', count: 3)
  end
end
