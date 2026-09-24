require 'rails_helper'

RSpec.describe('Student sends a message by pressing enter', :js, type: :system) do
  let!(:student) { create(:student, automatic_verified: true) }

  before do
    student.user.update!(onboarded: true)
    sign_in_as_student(student)
  end

  it 'student sends a message by pressing Enter' do
    visit(user_messages_path)
    fill_in(I18n.t('activerecord.attributes.user_message.body'), with: 'Hej, kan I hjælpe mig?')
    find_field(I18n.t('activerecord.attributes.user_message.body')).send_keys(:enter)
    expect(page).to(have_content(I18n.t('messages.create.success')))
    expect(UserMessage.count).to(eq(1))
  end
end
