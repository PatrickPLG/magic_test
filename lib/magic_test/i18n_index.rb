require "i18n"

module MagicTest
  # Reverse lookup from rendered text to I18n keys for one locale, built from
  # what `I18n.t` actually returns (the backend's merged translation tree), so
  # duplicate `activerecord.attributes` blocks resolve the way Rails does:
  # last loaded wins.
  class I18nIndex
    Match = Struct.new(:key, :interpolations)

    attr_reader :locale

    def initialize(locale = I18n.locale)
      @locale = locale.to_sym
      @exact = Hash.new { |h, k| h[k] = [] }
      @patterns = []
      build
    end

    # Exact (whitespace-normalised) matches first, then interpolated patterns.
    # Returns [] when nothing matches.
    def lookup(text)
      normalised = self.class.normalise(text)
      return [] if normalised.empty?
      keys = @exact[normalised]
      return keys.map { |k| Match.new(key: k, interpolations: {}) } if keys.any?
      @patterns.filter_map do |key, regexp, names|
        m = regexp.match(normalised)
        next unless m
        Match.new(key: key, interpolations: names.zip(m.captures.map(&:strip)).to_h)
      end
    end

    # Picks one key or nil, preferring the rendering template's lazy-lookup
    # scope, then a scope containing the controller namespace, then the
    # shortest key. `scopes` are strings like "institutions.events.index".
    def best(text, scopes: [], namespace: nil)
      matches = lookup(text)
      matches = strip_required_mark_and_retry(text) if matches.empty?
      return [nil, []] if matches.empty?
      return [matches.first, matches] if matches.size == 1
      # Lazy-lookup scope of the rendering template, then its suffixes
      # (`backoffice.leads.index` also covers `leads.index.*`), then the
      # template's top-level namespace.
      prefixes = scopes.flat_map do |s|
        segments = s.split(".")
        (0..[segments.size - 2, 0].max).map { |i| segments[i..].join(".") }
      end.uniq
      prefixes.each do |prefix|
        scoped = matches.select { |m| m.key.start_with?("#{prefix}.") }
        return [scoped.first, matches] if scoped.size == 1
      end
      lazy = matches.select { |m| scopes.any? { |s| m.key.start_with?("#{s.split(".").first}.") } }
      return [lazy.first, matches] if lazy.size == 1
      # Model names implied by the rendering templates (`providers/admin/discounts/edit`
      # → discount) pick `activerecord.attributes.discount.*` / `simple_form.labels.discount.*`.
      actions = scopes.map { |s| s.split(".").last }
      if matches.all? { |m| m.key.start_with?("helpers.submit.") }
        wanted = if (actions & %w[new create]).any?
          "create"
        else
          ((actions & %w[edit update]).any? ? "update" : nil)
        end
        by_action = matches.select { |m| m.key.end_with?(".#{wanted}") } if wanted
        return [by_action.first, matches] if by_action && by_action.size == 1
      end
      models = scopes.map { |s| s.split(".")[-2] }.compact.map { |dir| dir.singularize }.uniq
      models.each do |model|
        by_model = matches.select { |m| m.key.include?(".#{model}.") || m.key.include?("/#{model}.") || m.key.include?("_#{model}.") }
        return [by_model.first, matches] if by_model.size == 1
      end
      if namespace
        ns = matches.select { |m| m.key.include?(namespace.to_s) }
        return [ns.first, matches] if ns.size == 1
      end
      [nil, matches]
    end

    def self.normalise(text)
      text.to_s.gsub(/[[:space:]]+/, " ").strip
    end

    def size
      @exact.size
    end

    private

    def strip_required_mark_and_retry(text)
      stripped = text.to_s.sub(/\A\*\s*/, "")
      return [] if stripped == text.to_s
      lookup(stripped)
    end

    def build
      backend = I18n.backend
      backend.send(:init_translations) if backend.respond_to?(:init_translations, true) && !backend.initialized?
      tree = translations_for(backend)
      walk(tree, [])
    end

    def translations_for(backend)
      if backend.respond_to?(:translations)
        backend.translations[locale] || {}
      elsif backend.respond_to?(:backends) # Chain
        backend.backends.reverse.each_with_object({}) { |b, memo| memo.deep_merge!(translations_for(b)) }
      else
        {}
      end
    end

    def walk(node, path)
      case node
      when Hash
        node.each { |k, v| walk(v, path + [k.to_s]) }
      when String
        add(path.join("."), node)
      end
    end

    def add(key, value)
      return if key.start_with?("routes.", "date.", "time.", "number.", "datetime.", "support.", "faker.")
      normalised = self.class.normalise(value)
      return if normalised.empty?
      if value.include?("%{")
        names = value.scan(/%\{(\w+)\}/).flatten
        parts = normalised.split(/%\{\w+\}/, -1).map { |p| Regexp.escape(p) }
        # `%{attribute} %{message}` (Rails' errors.format) would match any
        # two words: a template needs literal text to be a usable key.
        return unless parts.any? { |p| p.match?(/\p{Alnum}/) }
        regexp = Regexp.new("\\A" + parts.join("(.+?)") + "\\z")
        @patterns << [key, regexp, names]
      else
        @exact[normalised] << key unless @exact[normalised].include?(key)
      end
    end
  end
end
