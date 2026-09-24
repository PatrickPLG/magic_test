# Verbatim shape of Studiz's spec/support/system_auth_helper.rb (Appendix B).
module SystemAuthHelper
  def sign_in_as_provider(provider = nil)
    provider ||= create(:provider)
    provider.user.ensure_authentication_token
    sign_in provider.user
    page.driver.set_cookie("auth_token", provider.user.authentication_token)
    page.driver.set_cookie("cookie_settings", "necessary")
  end

  def sign_in_as_student(student = nil)
    student ||= create(:student, automatic_verified: true)
    student.user.ensure_authentication_token
    sign_in student.user
    page.driver.set_cookie("auth_token", student.user.authentication_token)
    page.driver.set_cookie("cookie_settings", "necessary")
  end

  def sign_in_as_institution(institution)
    user = institution.leader.user
    user.ensure_authentication_token
    sign_in user
    page.driver.set_cookie("auth_token", user.authentication_token)
    page.driver.set_cookie("cookie_settings", "necessary")
  end

  def sign_in_as_student_organisation(organisation = nil)
    organisation ||= create(:student_organisation)
    organisation.user.ensure_authentication_token
    sign_in organisation.user
    page.driver.set_cookie("auth_token", organisation.user.authentication_token)
    page.driver.set_cookie("cookie_settings", "necessary")
  end
end

RSpec.configure do |config|
  config.include SystemAuthHelper, type: :system
end
