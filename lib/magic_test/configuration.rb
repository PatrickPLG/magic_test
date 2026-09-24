module MagicTest
  # Session-wide knobs. Everything has a Studiz-appropriate default; the
  # toolbar can flip `i18n_keys` per session.
  class Configuration
    attr_accessor :i18n_keys, :assertion_style, :locale, :fixture_files_dir,
      :ignored_request_paths, :window_size, :poll_interval_ms, :max_ancestor_depth,
      :command_timeout, :studiz_modals

    def initialize
      @i18n_keys = true
      @assertion_style = :house # `expect(Model.count).to(eq(n))`; :change offers the block form first
      @locale = nil # defaults to the request locale (usually :da)
      @fixture_files_dir = "spec/fixtures/files"
      @ignored_request_paths = [%r{\A/__magic_test}, %r{\A/live_support}, %r{\A/cable}, %r{\A/assets}, %r{\A/packs}, %r{\A/vendor}, %r{\A/js/}, %r{\A/css/}, %r{\A/rails/active_storage}]
      @window_size = [1200, 800]
      @poll_interval_ms = 700
      @max_ancestor_depth = 8
      @command_timeout = 20
      @studiz_modals = %w[#ajax-modal #full-view-modal #image-cropper-modal]
    end
  end
end
