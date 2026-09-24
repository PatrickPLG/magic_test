# Recorded by `rake docs:screenshots` (a copy under tmp/ is what actually runs,
# because the recorder writes the steps into the spec it records).
require 'rails_helper'

RSpec.describe('README screenshots', :js, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:discount) { create(:discount, provider: provider, name_da: 'Kaffe 20%', status: 'draft') }
  let!(:categories) { %w[Fest Foredrag Sport Kultur Musik].map { |n| create(:category, name: n) } }

  before do
    sign_in_as_provider(provider)
  end

  it 'provider edits a discount with the toolbar visible' do
    visit(edit_provider_admin_discount_path(provider, discount))
    magic_test
  end
end
