require "devise/orm/active_record"

Devise.setup do |config|
  config.secret_key = "fixture-app-devise-secret-fixture-app-devise-secret-0123456789abcdef"
  config.mailer_sender = "noreply@studiz.example"
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = 1
  config.reconfirmable = false
  config.password_length = 6..128
  config.sign_out_via = :delete
  config.navigational_formats = ["*/*", :html]
end
