module MagicTest
  # rspec-rails' `driven_by :cuprite` (in Studiz's `before` blocks) re-registers
  # the :cuprite driver with Rails defaults, which discards the rails_helper
  # registration's `headless: ENV['MAGIC_TEST'] ? false : …` and window size.
  # Under MAGIC_TEST the gem therefore forces the recording essentials itself.
  module CupriteDefaults
    def initialize(app, options = {})
      options = options.dup
      if MagicTest.enabled?
        options[:headless] = MagicTest.headless? unless ENV["MAGIC_TEST_HEADLESS"].nil? && options.key?(:headless) && options[:headless] == false
        options[:headless] = false unless MagicTest.headless?
        options[:window_size] ||= MagicTest.config.window_size
        options[:process_timeout] = [options[:process_timeout].to_i, 30].max
        options[:timeout] = [options[:timeout].to_i, 15].max
      end
      super
    end

    def self.install!
      return if @installed
      require "capybara/cuprite"
      Capybara::Cuprite::Driver.prepend(self)
      @installed = true
    end
  end
end
