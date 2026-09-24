module MagicTest
  # Studiz keeps byte-identical copies of the old recorder partials in
  # app/views/magic_test. App views shadow engine views, so the old recorder
  # would load next to the new one. Warn loudly at boot; the JS also refuses
  # to run twice (see src/99_boot.js).
  module LegacyOverrideCheck
    LEGACY_FILES = %w[_context_menu.html.erb _finders.html _javascript_helpers.html _key_codes.html _listeners.html _mutation_observer.html _storage.html].freeze

    module_function

    def run(root = Rails.root)
      dir = root.join("app/views/magic_test")
      return nil unless dir.directory?
      files = Dir.children(dir)
      legacy = files & LEGACY_FILES
      return nil if legacy.empty? && !files.include?("_support.html.erb")
      MagicTest.warn_legacy_override!(dir.to_s)
    end
  end
end
