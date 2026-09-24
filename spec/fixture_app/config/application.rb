require_relative "boot"

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"

# Mirrors Studiz: the gem sits in the :test Bundler group and is picked up by
# Bundler.require, not by an explicit require in the spec helpers.
Bundler.require(*Rails.groups)

module FixtureApp
  # A faithful, minimal replica of the Studiz Rails app (Rails 7.0.8, HAML,
  # simple_form/Bootstrap 5, Devise with polymorphic roles, route_translator,
  # Chosen, flatpickr, Trix, Cropper, rails-ujs, Bootstrap modals + toasts).
  class Application < Rails::Application
    config.load_defaults 7.0
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.cache_classes = true

    config.i18n.available_locales = [:da, :en]
    config.i18n.default_locale = :da
    config.i18n.load_path += Dir[File.expand_path("locales/**/*.yml", __dir__)]

    config.secret_key_base = "fixture-app-secret-key-base-fixture-app-secret-key-base-0123456789"
    config.session_store :cookie_store, key: "_fixture_app_session"

    config.public_file_server.enabled = true
    config.consider_all_requests_local = true
    config.action_dispatch.show_exceptions = false
    config.action_controller.allow_forgery_protection = false
    config.action_controller.perform_caching = false
    config.action_mailer.delivery_method = :test
    config.action_mailer.default_url_options = {host: "127.0.0.1"}
    config.active_support.deprecation = :stderr
    config.active_record.dump_schema_after_migration = false
    config.log_level = :warn
    config.logger = ActiveSupport::Logger.new(File.expand_path("../log/test.log", __dir__))
    config.filter_parameters += [:password]
  end
end

RouteTranslator.config do |config|
  config.available_locales = [:da, :en]
  # Default `hide_locale = false`: the default locale (da) is unprefixed, `/en/...` is prefixed, as in Studiz.
end
