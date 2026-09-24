module MagicTest
  # Optional Pry integration. Pry is not a dependency: Studiz bundles it, and
  # the console is only offered when `defined?(Pry)`.
  module Console
    module_function

    def available?
      defined?(::Pry) ? true : false
    end

    # Opens Pry on the given binding with `flush`/`ok` available.
    def open(binding_)
      return false unless available?
      puts "magic_test: console open. `flush` writes pending steps, `ok` writes the last line you typed, Ctrl+D returns to the toolbar."
      binding_.pry
      true
    end

    # Last non-trivial line typed into the console (used by `ok`).
    def last_input
      return @last_input unless available?
      history = ::Pry.history.to_a.reject { |l| l.strip.empty? || %w[ok flush exit exit! quit].include?(l.strip) }
      history.last
    end

    def last_input=(value)
      @last_input = value
    end
  end
end
