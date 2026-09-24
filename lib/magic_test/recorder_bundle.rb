module MagicTest
  # Concatenates the recorder's ES2017 source modules into one IIFE that
  # exposes only `window.MagicTest`. No Node, no build step: the engine serves
  # this at /__magic_test/recorder.js and caches it per process.
  module RecorderBundle
    SRC_DIR = File.expand_path("../../app/assets/javascripts/magic_test/src", __dir__)

    module_function

    def source_files
      Dir[File.join(SRC_DIR, "**", "*.js")].sort_by { |f| f.sub(SRC_DIR, "") }
    end

    def build
      modules = source_files.map do |file|
        name = file.sub("#{SRC_DIR}/", "")
        "// ---- #{name} ----\n#{File.read(file)}\n"
      end
      <<~JS
        /* magic_test recorder #{MagicTest::VERSION} — generated bundle, edit app/assets/javascripts/magic_test/src */
        (function () {
          'use strict';
          if (window.MagicTest && window.MagicTest.__loaded) { return; }
          var MT = { version: #{MagicTest::VERSION.inspect}, modules: {}, listeners: [] };
        #{modules.join("\n")}
          MT.boot();
        })();
      JS
    end

    def cached
      @cached = nil if ENV["MAGIC_TEST_DEV"].present?
      @cached ||= build
    end

    def write(path)
      File.write(path, build)
      path
    end
  end
end
