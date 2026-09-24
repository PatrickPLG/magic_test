require "magic_test/middleware"
require "magic_test/db_changes"
require "magic_test/route_resolver"
require "magic_test/legacy_override_check"
require "magic_test/cuprite_defaults"

module MagicTest
  class Engine < Rails::Engine
    isolate_namespace MagicTest

    initializer "magic_test.middleware" do |app|
      app.middleware.use MagicTest::Middleware if MagicTest.enabled?
    end

    initializer "magic_test.routes" do |app|
      if MagicTest.enabled?
        app.routes.prepend do
          mount MagicTest::Engine => "/__magic_test", :as => :magic_test
        end
      end
    end

    config.after_initialize do
      if MagicTest.rails_env_test?
        # Helpers load in every test run, so generated code never depends on MAGIC_TEST.
        if defined?(RSpec) && RSpec.respond_to?(:configure)
          RSpec.configure do |config|
            config.include MagicTest::Helpers, type: :system
            config.include MagicTest::Support, type: :system if MagicTest.enabled?
          end
        end
        ActiveSupport.on_load(:action_dispatch_system_test_case) do
          include MagicTest::Helpers
        end
      end

      if MagicTest.enabled?
        MagicTest::LegacyOverrideCheck.run
        MagicTest::Middleware.subscribe!
        MagicTest::CupriteDefaults.install!
        require "magic_test/session"
      end
    end
  end
end
