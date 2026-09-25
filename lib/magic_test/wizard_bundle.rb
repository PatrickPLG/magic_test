module MagicTest
  # The wizard page: one HTML document plus one JS bundle concatenated from
  # app/assets/javascripts/magic_test/wizard/*.js, served by the engine at
  # /__magic_test/new and /__magic_test/wizard.js. No build step.
  module WizardBundle
    SRC_DIR = File.expand_path("../../app/assets/javascripts/magic_test/wizard", __dir__)
    PAGE = File.expand_path("wizard/page.html", __dir__)

    module_function

    def source_files
      Dir[File.join(SRC_DIR, "*.js")].sort
    end

    def build
      modules = source_files.map { |f| "// ---- #{File.basename(f)} ----\n#{File.read(f)}\n" }
      "/* magic_test wizard #{MagicTest::VERSION} */\n(function () {\n'use strict';\nvar W = { version: #{MagicTest::VERSION.inspect} };\n#{modules.join("\n")}\nW.boot();\n})();\n"
    end

    def cached
      @cached = nil if ENV["MAGIC_TEST_DEV"].present?
      @cached ||= build
    end

    def page_html
      File.read(PAGE).sub("__VERSION__", MagicTest::VERSION)
    end
  end
end
