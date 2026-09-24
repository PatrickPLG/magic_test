require "magic_test/version"

module MagicTest
  class Error < StandardError; end
end

require "magic_test/configuration"
require "magic_test/ruby_literal"
require "magic_test/dynamic_values"
require "magic_test/helpers"
require "magic_test/support"
require "magic_test/call_site"
require "magic_test/request_log"
require "magic_test/event_log"
require "magic_test/i18n_index"
require "magic_test/codegen"
require "magic_test/spec_writer"
require "magic_test/console"
require "magic_test/recorder_bundle"
require "magic_test/railtie" if defined?(Rails::Railtie)

# Record-and-replay RSpec system-test generator for the Studiz Rails app.
#
# Everything that needs Rails, Capybara or the recording session is required
# lazily by the engine (lib/magic_test/engine.rb) so that `require "magic_test"`
# stays cheap and side-effect free outside of a MAGIC_TEST run.
module MagicTest
  class << self
    # True when a recording session may run: test environment + MAGIC_TEST set.
    def enabled?
      rails_env_test? && ENV["MAGIC_TEST"].present?
    end

    # Headed Chrome is the default for MAGIC_TEST; MAGIC_TEST_HEADLESS=1 is the
    # escape hatch for CI and the scripted-human harness.
    def headless?
      ENV["MAGIC_TEST_HEADLESS"].present?
    end

    def rails_env_test?
      defined?(Rails) && Rails.respond_to?(:env) && Rails.env.test?
    end

    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    attr_accessor :current_session

    def session
      current_session
    end

    # Requests seen before a session exists (the spec's own `visit` before
    # `magic_test`); a new session adopts the recent ones.
    def pre_session_request_log
      @pre_session_request_log ||= RequestLog.new
    end

    def logger
      @logger ||= (defined?(Rails) && Rails.logger) || Logger.new($stdout)
    end

    # Loud, specific warning for the one unavoidable Studiz change.
    def warn_legacy_override!(dir)
      message = <<~MSG
        ================================================================================
        magic_test: #{dir} exists.
        Those files are byte-identical copies of the OLD recorder partials and shadow
        the engine's views, so the old recorder would load next to the new one.
        Delete the directory (see MIGRATION_STUDIZ.md, step 1):

            git rm -r #{dir}

        ================================================================================
      MSG
      warn(message)
      logger.warn(message)
      message
    end
  end
end

require "magic_test/engine" if defined?(Rails::Engine)
