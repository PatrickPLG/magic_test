require "yaml"

module MagicTest
  # The "?" hints of the wizard and the toolbar (1.2 §6), from config/hints.yml.
  # Each hint has one plain sentence, when to use it and a short Ruby example.
  module Hints
    PATH = File.expand_path("../../config/hints.yml", __dir__)
    PARTS = %w[text when example].freeze

    module_function

    def all
      @all ||= YAML.safe_load_file(PATH) || {}
    end

    def reload!
      @all = nil
      all
    end

    # "wizard.trait" → the hint hash, or nil.
    def for(key)
      section, name = key.to_s.split(".", 2)
      all.dig(section, name)
    end

    def keys
      all.flat_map { |section, hints| hints.keys.map { |k| "#{section}.#{k}" } }
    end

    # What the pages receive: {"wizard" => {...}, "toolbar" => {...}}.
    def payload(section = nil)
      section ? all.fetch(section.to_s, {}) : all
    end

    # Every hint must have all parts, and the text must be one sentence.
    def problems
      all.flat_map do |section, hints|
        hints.flat_map do |name, hint|
          key = "#{section}.#{name}"
          issues = PARTS.reject { |p| hint.is_a?(Hash) && hint[p].to_s.strip != "" }.map { |p| "#{key} lacks #{p}" }
          issues << "#{key} text is more than one sentence" if hint.is_a?(Hash) && hint["text"].to_s.strip.scan(/[.!?](?=\s+[A-Z]|\s*\z)/).size > 1 # "let! creates" is not a sentence end
          issues << "#{key} example is longer than 3 lines" if hint.is_a?(Hash) && hint["example"].to_s.strip.lines.size > 3
          issues
        end
      end
    end
  end
end
