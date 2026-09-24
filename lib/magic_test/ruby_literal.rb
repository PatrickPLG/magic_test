require "date"

module MagicTest
  # Renders Ruby literals for generated code. Single quotes when nothing needs
  # escaping (Studiz style), otherwise String#inspect (which handles quotes,
  # backslashes, control characters, newlines and `#{`).
  module RubyLiteral
    SINGLE_QUOTE_SAFE = /\A[^'\\\p{Cntrl}]*\z/

    module_function

    def string(value)
      value = value.to_s
      return "'#{value}'" if value.match?(SINGLE_QUOTE_SAFE)
      value.inspect
    end

    def symbol(value)
      value = value.to_s
      value.match?(/\A[A-Za-z_][A-Za-z0-9_]*[?!]?\z/) ? ":#{value}" : ":#{value.inspect}"
    end

    def value(obj)
      case obj
      when String then string(obj)
      when Symbol then symbol(obj)
      when Integer, Float, true, false, nil then obj.inspect
      when Date then "Date.new(#{obj.year}, #{obj.month}, #{obj.day})"
      when Time then "Time.zone.parse(#{string(obj.strftime("%Y-%m-%d %H:%M:%S"))})"
      when Array then "[#{obj.map { |o| value(o) }.join(", ")}]"
      when Hash then obj.map { |k, v| "#{k}: #{value(v)}" }.join(", ")
      else obj.to_s
      end
    end

    # Keyword arguments rendered as `key: value` pairs.
    def kwargs(hash)
      hash.map { |k, v| "#{k}: #{value(v)}" }.join(", ")
    end

    # Capybara-style locator: a literal string, or a raw expression such as
    # `I18n.t('key')` passed through untouched.
    def locator(loc)
      loc.is_a?(RawCode) ? loc.to_s : string(loc)
    end

    # A snippet of Ruby that must not be quoted again.
    class RawCode
      attr_reader :code
      def initialize(code)
        @code = code
      end

      def to_s
        code
      end

      def ==(other)
        other.is_a?(RawCode) && other.code == code
      end
    end

    def raw(code)
      RawCode.new(code)
    end
  end
end
