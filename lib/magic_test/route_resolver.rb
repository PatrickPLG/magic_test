module MagicTest
  # Maps a request path back to a named route helper and its arguments, and
  # replaces record ids in those arguments with the example's memoised `let`
  # variables. Never emits a literal database id.
  class RouteResolver
    Result = Struct.new(:helper, :args, :query, :review, :locale, :route_name) do
      # Ruby source for the helper call, e.g. `institution_events_path(institution)`.
      def code
        return nil unless helper
        parts = args.map(&:code)
        parts << RubyLiteral.kwargs(query) if query.present?
        parts.empty? ? helper : "#{helper}(#{parts.join(", ")})"
      end

      def review?
        review.present? || args.any?(&:review?)
      end
    end

    Arg = Struct.new(:name, :value, :code, :review) do
      def review?
        review.present?
      end
    end

    def initialize(routes = Rails.application.routes, url_helpers: nil)
      @routes = routes
      @url_helpers = url_helpers || routes.url_helpers
    end

    # @param path [String] request path (no host), may include a query string
    # @param method [Symbol]
    # @param memoized [Hash{Symbol=>Object}] the example's let variables
    def resolve(path, method: :get, memoized: {})
      uri = URI.parse(path.to_s)
      route, match = find_route(uri.path, method)
      return Result.new(helper: nil, args: [], query: {}, review: "no named route for #{uri.path}") unless route

      values = match_values(route, match)
      locale = route.defaults[:locale]&.to_s
      helper_base = agnostic_helper_name(route.name, locale)
      args = route.required_parts.map { |part| arg_for(part, values[part], route, memoized) }
      query = query_hash(uri.query)
      Result.new(helper: "#{helper_base}_path", args: args, query: query, locale: locale, route_name: route.name)
    end

    def agnostic_helper_name(name, locale)
      return name unless locale && name.end_with?("_#{locale}")
      base = name.sub(/_#{locale}\z/, "")
      default = I18n.default_locale.to_s
      # Studiz style: locale-agnostic helper for the default locale, explicit
      # `_en` helper for the prefixed locale (the agnostic one follows I18n.locale
      # at call time, which is :da in specs).
      return name if locale != default
      @url_helpers.respond_to?("#{base}_path") ? base : name
    end

    private

    def find_route(path, method)
      verb = method.to_s.upcase
      candidates = @routes.routes.select do |r|
        next false if r.name.nil? || r.internal
        verb_ok = r.verb.blank? || r.verb.to_s.split("|").include?(verb) || (r.verb.is_a?(Regexp) && r.verb.match?(verb))
        next false unless verb_ok
        r.path.match(path)
      end
      candidates = candidates.select { |r| r.path.match(path).names.zip(r.path.match(path).captures).all? { |n, v| requirement_ok?(r, n, v) } }
      # Prefer the most specific pattern (more static segments), then ones with a controller.
      route = candidates.min_by { |r| [-r.path.spec.to_s.count("/"), r.path.spec.to_s.include?("*") ? 1 : 0, r.required_parts.size] }
      return [nil, nil] unless route
      [route, route.path.match(path)]
    end

    def requirement_ok?(route, name, value)
      req = route.requirements[name.to_sym]
      return true if req.nil? || value.nil?
      req.is_a?(Regexp) ? req.match?(value) : req.to_s == value.to_s
    end

    def match_values(route, match)
      match.names.zip(match.captures).to_h { |n, v| [n.to_sym, v && Rack::Utils.unescape(v)] }
    end

    def query_hash(query)
      return {} if query.blank?
      Rack::Utils.parse_nested_query(query).to_h { |k, v| [k.to_sym, v] }
    end

    def arg_for(part, value, route, memoized)
      candidates = memoized_records_for(part, value, route, memoized)
      if candidates.size == 1
        name, _record = candidates.first
        Arg.new(name: part, value: value, code: name.to_s)
      elsif value.to_s.match?(/\A\d+\z/)
        model = model_guess(part, route)
        if candidates.any?
          # Several lets share the id: the one named like the resource wins, else say so.
          resource = resource_name(part, route)
          named = candidates.find { |n, v| n.to_s == resource || v.class.name.demodulize.underscore == resource }
          return Arg.new(name: part, value: value, code: (named || candidates.first).first.to_s, review: named ? nil : "ambiguous: #{candidates.map(&:first).join(", ")} all have id #{value}")
        end
        review = "no `let` holds the record with id #{value} for :#{part}; replace `#{model || "Model"}.find(#{value})` with a let variable"
        Arg.new(name: part, value: value, code: "#{model || "Record"}.find(#{value})", review: review)
      else
        Arg.new(name: part, value: value, code: RubyLiteral.string(value))
      end
    end

    def resource_name(part, route)
      return part.to_s.sub(/_id\z/, "") unless part.to_s == "id"
      route.defaults[:controller].to_s.split("/").last.to_s.singularize
    end

    # Memoised lets whose record id equals the value. The param name narrows the
    # model (`institution_id` → Institution); `:id` accepts any model, so an
    # ambiguity is possible and reported.
    def memoized_records_for(part, value, route, memoized)
      return [] if value.nil?
      records = memoized.select { |_name, v| active_record?(v) && v.id.to_s == value.to_s }
      return records.to_a if records.size <= 1
      wanted = model_guess(part, route)
      wanted_class = wanted&.safe_constantize
      narrowed = records.select { |_n, v| wanted_class && v.instance_of?(wanted_class) }
      (narrowed.size == 1) ? narrowed.to_a : records.to_a
    end

    def model_guess(part, route)
      return nil unless defined?(ActiveRecord::Base)
      base = if part.to_s == "id"
        route.defaults[:controller].to_s.split("/").last.to_s.singularize
      else
        part.to_s.sub(/_id\z/, "")
      end
      controller = route.defaults[:controller].to_s
      guesses = [base.camelize]
      guesses << "#{base.pluralize.camelize}::#{base.camelize}" # Studiz: Events::Event, Institutions::Employee
      guesses << "#{controller.split("/").first.to_s.camelize}::#{base.camelize}" if controller.include?("/")
      guesses << "#{controller.split("/").last.to_s.camelize}::#{base.camelize}" if controller.include?("/")
      klass = guesses.map(&:safe_constantize).find { |k| k.is_a?(Class) && k < ActiveRecord::Base }
      klass&.name
    end

    def active_record?(obj)
      defined?(ActiveRecord::Base) && obj.is_a?(ActiveRecord::Base) && obj.respond_to?(:id)
    end
  end
end
