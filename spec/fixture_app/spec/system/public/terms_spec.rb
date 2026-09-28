require 'rails_helper'

RSpec.describe('Terms page', :js, type: :system) do
  before { driven_by :cuprite }

  it 'shows the terms' do
    visit terms_path
    expect(page).to have_content('misbrug')
  end
end
