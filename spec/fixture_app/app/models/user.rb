# One Devise model with a polymorphic role, exactly like Studiz.
class User < ApplicationRecord
  devise :database_authenticatable, :rememberable
  include Flipper::Identifier # Studiz gates flags per user (flipper_id = "User;<id>")

  belongs_to :role, polymorphic: true, optional: true
  has_many :user_messages, dependent: :destroy

  def ensure_authentication_token
    update_column(:authentication_token, SecureRandom.hex(16)) if authentication_token.blank?
    authentication_token
  end

  def student?
    role_type == "Student"
  end
end
