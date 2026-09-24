module MagicTest
  module Codegen
    # Chooses the best verified-unique locator among the candidates the
    # browser computed (each carries Capybara-semantics match counts, globally
    # and inside candidate scopes). Applies the dynamic-value filter again on
    # the Ruby side and resolves I18n keys.
    class LocatorPicker
      Choice = Struct.new(:code, :kind, :by, :scope, :confidence, :review, :i18n_key, :literal, :alternatives, :unique)

      SEMANTIC_BY_ORDER = %w[label text own_text i18n id name placeholder title value alt].freeze
      SCOPE_ORDER = %w[modal form row heading ancestor nth].freeze

      def initialize(known_ids:, i18n_index:, i18n_keys: true, template_scopes: [], namespace: nil, i18n_locale: nil)
        @known_ids = known_ids
        @i18n = i18n_index
        @i18n_locale = i18n_locale
        @i18n_keys = i18n_keys
        @template_scopes = template_scopes
        @namespace = namespace
      end

      # @param candidates [Array<Hash>] from the browser
      # @param kinds [Array<String>] acceptable Capybara selector kinds for this action
      # @param i18n [Boolean] per-step override of the I18n toggle
      def pick(candidates, kinds:, i18n: true, allow_css: true)
        usable = Array(candidates).map { |c| normalise(c) }.reject { |c| dynamic?(c) }
        semantic = usable.select { |c| kinds.include?(c["kind"]) }
        choice = pick_global(semantic, i18n) || pick_scoped(semantic, i18n)
        if choice.nil? && allow_css
          css = usable.select { |c| c["kind"] == "css" }
          choice = pick_css(css)
        end
        choice ||= pick_positional(usable) if allow_css
        choice ||= fallback(usable, kinds)
        choice.alternatives = alternatives_for(usable, kinds, i18n)
        choice
      end

      private

      def normalise(c)
        c = c.transform_keys(&:to_s)
        c["exact"] = c["exact"].to_i
        c["partial"] = c["partial"].to_i
        c["unique"] = unique?(c["exact"], c["partial"], c["exact_supported"] != false)
        c
      end

      # Capybara `match: :smart`: exact matches win when present, otherwise
      # partial matches; exactly one is required.
      def unique?(exact, partial, exact_supported)
        return partial == 1 unless exact_supported
        exact == 1 || (exact.zero? && partial == 1)
      end

      def dynamic?(c)
        val = c["locator"].to_s
        case c["by"]
        when "id", "name", "css" then DynamicValues.dynamic?(val, @known_ids)
        else false
        end
      end

      def pick_global(semantic, i18n)
        ordered = semantic.select { |c| c["scope"].nil? && c["unique"] }.sort_by { |c| by_rank(c) }
        c = ordered.first
        return nil unless c
        build(c, :green, i18n)
      end

      def pick_scoped(semantic, i18n)
        scoped = semantic.select { |c| c["scope"] && c["unique"] }
        return nil if scoped.empty?
        c = scoped.min_by { |x| [SCOPE_ORDER.index(x.dig("scope", "kind").to_s) || 99, by_rank(x)] }
        build(c, :amber, i18n)
      end

      # The browser emits CSS candidates in preference order (id, name, data
      # attributes, href, class combinations, single classes); keep that order,
      # prefer global over scoped and selector-only over selector+text.
      def pick_css(css)
        c = css.each_with_index.select { |x, _i| x["unique"] }.min_by { |x, i| [x["scope"] ? 1 : 0, x["text"].present? ? 1 : 0, i] }&.first
        return nil unless c
        Choice.new(code: css_code(c), kind: "css", by: "css", scope: c["scope"], confidence: :amber, review: nil, unique: true)
      end

      def pick_positional(usable)
        c = usable.find { |x| x["kind"] == "positional" && x["unique"] }
        return nil unless c
        Choice.new(code: css_code(c), kind: "css", by: "positional", scope: c["scope"], confidence: :red,
          review: "positional selector #{c["locator"].inspect}; add a stable id or data attribute", unique: true)
      end

      def fallback(usable, kinds)
        c = usable.find { |x| kinds.include?(x["kind"]) } || usable.first
        if c
          Choice.new(code: (c["kind"] == "css") ? css_code(c) : RubyLiteral.string(c["locator"]), kind: c["kind"], by: c["by"], scope: c["scope"], confidence: :red,
            review: "locator #{c["locator"].inspect} matches #{[c["exact"], c["partial"]].max} elements; make it unique", unique: false)
        else
          Choice.new(code: "'?'", kind: "css", by: "none", scope: nil, confidence: :red, review: "no locator could be computed for this element", unique: false)
        end
      end

      def by_rank(c)
        SEMANTIC_BY_ORDER.index(c["by"].to_s) || 50
      end

      def build(c, confidence, i18n)
        key = nil
        literal = c["locator"]
        code = RubyLiteral.string(literal)
        review = nil
        if %w[text own_text label title value alt].include?(c["by"]) && @i18n && @i18n_keys && i18n
          best, matches = @i18n.best(literal, scopes: @template_scopes, namespace: @namespace)
          if best
            key = best.key
            code = i18n_code(best)
          elsif matches.size > 1
            review = "several I18n keys render #{literal.inspect}: #{matches.map(&:key).join(", ")}"
            confidence = :amber if confidence == :green
          end
        end
        Choice.new(code: code, kind: c["kind"], by: c["by"], scope: c["scope"], confidence: confidence,
          review: review, i18n_key: key, literal: literal, unique: true)
      end

      def i18n_code(match)
        Codegen.t_code(match.key, match.interpolations, @i18n_locale)
      end

      def css_code(c)
        parts = [RubyLiteral.string(c["locator"])]
        parts << "text: #{RubyLiteral.string(c["text"])}" if c["text"].present?
        parts.join(", ")
      end

      def alternatives_for(usable, kinds, i18n)
        usable.select { |c| c["unique"] }.first(8).map do |c|
          code = (c["kind"] == "css" || c["kind"] == "positional") ? css_code(c) : RubyLiteral.string(c["locator"])
          scope = c["scope"] ? " (within #{c.dig("scope", "css")}#{" text: #{c.dig("scope", "text").inspect}" if c.dig("scope", "text")})" : ""
          {"code" => code, "label" => "#{c["kind"]} by #{c["by"]}#{scope}", "candidate" => c}
        end
      end
    end
  end
end
