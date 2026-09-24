class ApplicationController < ActionController::Base
  around_action :set_locale_from_url
  before_action :authenticate_from_auth_token_cookie
  helper_method :current_role, :current_student, :cookie_settings_accepted?

  private

  # Studiz keeps an `auth_token` cookie next to the Devise session; the auth
  # helpers set it explicitly (Appendix B). Honour it here so `magic_sign_in`
  # can be proven equivalent to `sign_in_as_*`.
  def authenticate_from_auth_token_cookie
    return if user_signed_in?
    token = cookies[:auth_token]
    return if token.blank?
    user = User.find_by(authentication_token: token)
    sign_in(user, store: false) if user
  end

  def current_role
    current_user&.role
  end

  def current_student
    current_role if current_role.is_a?(Student)
  end

  def cookie_settings_accepted?
    cookies[:cookie_settings].present?
  end

  def require_role!(*klasses)
    authenticate_user!
    return if klasses.any? { |k| current_role.is_a?(k) }
    render plain: "Forbudt", status: :forbidden
  end
end
