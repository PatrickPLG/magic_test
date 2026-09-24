require 'rails_helper'

RSpec.describe('Student records an explicit hover on the help menu, then clicks a revealed link', :js, type: :system) do
  it 'student records an explicit hover on the help menu, then clicks a revealed link' do
    visit(root_path)
    find_link(I18n.t('nav.help')).hover
    click_on(I18n.t('nav.help_terms'))
  end
end
