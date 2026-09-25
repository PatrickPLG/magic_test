require 'rails_helper'

# guest reads the terms in English
RSpec.describe('Guest reads the terms in English', :js, type: :system) do
  before do
    driven_by(:cuprite)
    page.driver.set_cookie('cookie_settings', 'necessary')
  end

  it 'guest reads the terms in English' do
    visit(terms_en_path)
    expect(page).to(have_content("Studiz' vilkår"))
    click_on('Tilbage')
    expect(page).to(have_current_path(root_en_path))
  end
end
