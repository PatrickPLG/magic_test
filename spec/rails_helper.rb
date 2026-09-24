# The gem's own test suite boots the Studiz replica in spec/fixture_app.
# Studiz's rails_helper.rb looks the same modulo paths (Appendix A).
require "spec_helper"
ENV["RAILS_ENV"] = "test"
require File.expand_path("fixture_app/config/environment", __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "capybara/rspec"
require "capybara/cuprite"
require "database_cleaner/active_record"
require "magic_test/testing/scripted_human"

# Fresh schema on every boot: the fixture app has no migrations.
ActiveRecord::Schema.verbose = false
load Rails.root.join("db/schema.rb")

Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |f| require f }

Capybara.default_driver = :cuprite # every system spec runs JS, like Studiz
Capybara.javascript_driver = :cuprite
Capybara.server = :puma, {Silent: true}
Capybara.default_max_wait_time = ENV["CI"] ? 10 : 5
Capybara.disable_animation = true
Capybara.server_errors = []
Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [1200, 800], **FixtureAppSupport::CUPRITE_OPTIONS)
end

RSpec.configure do |config|
  # Recorder-level specs (record -> generate in the browser) need the engine
  # booted with MAGIC_TEST set; they run in a second process:
  #   MAGIC_TEST=1 MAGIC_TEST_HEADLESS=1 bin/rspec --tag recorder
  config.filter_run_excluding(recorder: true) unless MagicTest.enabled?
  config.filter_run_excluding(no_recorder: true) if MagicTest.enabled?
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers, type: :system
  config.include Devise::Test::IntegrationHelpers, type: :system

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do |example|
    DatabaseCleaner.strategy = (example.metadata[:type] == :system) ? :truncation : :transaction
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.before(:each, type: :system) do
    # NOTE: rspec-rails' `driven_by` RE-REGISTERS the :cuprite driver with Rails
    # defaults (ActionDispatch::SystemTesting::Driver#register), so the options
    # must be passed here to take effect. See docs/DECISIONS.md.
    driven_by :cuprite, screen_size: [1200, 800], options: FixtureAppSupport::CUPRITE_OPTIONS.dup
  end
end
