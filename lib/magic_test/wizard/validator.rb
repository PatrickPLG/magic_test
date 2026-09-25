module MagicTest
  module Wizard
    # Checks a Plan against the Catalogue, auto-wires associations and orders
    # the lets so parents come first. Returns Issues; errors block preflight,
    # warnings are shown. Every issue carries a suggested fix.
    class Validator
      Issue = Struct.new(:severity, :field, :message, :fix, :data) do
        def error?
          severity == :error
        end

        def to_h
          {severity: severity, field: field, message: message, fix: fix, data: data}
        end
      end

      FACTORY_SENTINEL = "factory".freeze
      NONE_SENTINEL = "none".freeze

      attr_reader :plan, :catalogue, :issues

      def initialize(plan, catalogue)
        @plan = plan
        @catalogue = catalogue
        @issues = []
      end

      def self.validate(plan, catalogue)
        new(plan, catalogue).tap(&:run)
      end

      def run
        @issues = []
        check_description
        check_target
        check_models
        auto_wire!
        check_associations
        check_signed_in
        check_start
        check_extras
        check_order
        self
      end

      def errors
        issues.select(&:error?)
      end

      def warnings
        issues.reject(&:error?)
      end

      def valid?
        errors.empty?
      end

      # Lets in dependency order (parents first). Raises on a cycle.
      def ordered_models
        Ordering.order(plan.models)
      end

      # Fills each unset belongs_to with the one let of a matching class.
      def auto_wire!
        plan.models.each do |model|
          catalogue.associations_for(model.factory).each do |assoc|
            next if model.associations.key?(assoc.name)
            candidates = candidate_lets(model, assoc)
            model.associations[assoc.name] = candidates.first if candidates.size == 1
          end
        end
      end

      def candidate_lets(model, assoc)
        plan.models.reject { |m| m.let == model.let }.select do |other|
          klass = catalogue.klass_for(other.factory)
          next false unless klass
          assoc.polymorphic || (assoc.class_name && (klass <= assoc.class_name.safe_constantize || (assoc.class_name.safe_constantize.nil? && klass.name == assoc.class_name)))
        end.map(&:let)
      end

      private

      def add(severity, field, message, fix = nil, data = {})
        issues << Issue.new(severity: severity, field: field, message: message, fix: fix, data: data)
      end

      def check_description
        add(:error, "description", "Describe the test in a sentence.", "e.g. \"provider edits a discount\"") if plan.description.strip.empty?
      end

      def check_target
        path = plan.target.path.to_s
        return add(:error, "target.path", "Choose a spec file to write to.", "e.g. spec/system/provider/edits_discount_spec.rb") if path.empty?
        add(:error, "target.path", "The spec file must end with _spec.rb.", "rename it to #{File.basename(path, ".rb")}_spec.rb") unless path.end_with?("_spec.rb")
      end

      def check_models
        seen = {}
        plan.models.each_with_index do |model, i|
          field = "models[#{i}]"
          if !/\A[a-z_][a-z0-9_]*\z/.match?(model.let)
            add(:error, "#{field}.let", "\"#{model.let}\" is not a valid let name.", "use snake_case, e.g. #{model.let.to_s.parameterize(separator: "_").presence || "record"}")
          end
          add(:error, "#{field}.let", "Two models are called \"#{model.let}\".", "rename one of them") if seen[model.let]
          seen[model.let] = true
          factory = catalogue.factory(model.factory)
          unless factory
            near = catalogue.factories.map(&:name).select { |n| n.include?(model.factory.to_s[0, 4].to_s) }.first(5)
            add(:error, "#{field}.factory", "No factory called :#{model.factory}.", near.any? ? "did you mean #{near.map { |n| ":#{n}" }.join(", ")}?" : "check spec/factories")
            next
          end
          unknown = model.traits - factory.traits
          unknown.each do |t|
            add(:error, "#{field}.traits", "Factory :#{factory.name} has no trait :#{t}.", factory.traits.any? ? "known traits: #{factory.traits.map { |x| ":#{x}" }.join(", ")}" : "this factory defines no traits")
          end
          add(:error, "#{field}.count", "count must be at least 1.", "use 1 for a single record") if model.count < 1
          check_attributes(model, field)
        end
      end

      def check_attributes(model, field)
        columns = catalogue.attributes_for(model.factory)
        model.attributes.each do |name, value|
          unless catalogue.attribute_settable?(model.factory, name)
            add(:error, "#{field}.attributes.#{name}", "#{catalogue.factory(model.factory)&.class_name} has no attribute \"#{name}\".", "columns: #{columns.keys.first(12).join(", ")}")
            next
          end
          enum = columns.dig(name, :enum)
          if enum && !enum.include?(value.to_s)
            add(:error, "#{field}.attributes.#{name}", "\"#{value}\" is not a #{name} value.", "one of: #{enum.join(", ")}")
          end
        end
      end

      def check_associations
        plan.models.each_with_index do |model, i|
          field = "models[#{i}].associations"
          assocs = catalogue.associations_for(model.factory)
          model.associations.each do |name, target|
            assoc = assocs.find { |a| a.name == name }
            unless assoc
              add(:error, "#{field}.#{name}", "#{model.factory} has no belongs_to :#{name}.", "known: #{assocs.map(&:name).join(", ").presence || "none"}")
              next
            end
            case target
            when nil, NONE_SENTINEL
              if assoc.required?
                add(:error, "#{field}.#{name}", "#{name} cannot be none: #{assoc.foreign_key} is NOT NULL and the association is not optional.", "pick a let of class #{assoc.class_name}, or let the factory build it", {association: name})
              elsif target == NONE_SENTINEL
                add(:warning, "#{field}.#{name}", "#{name} will be nil.", nil, {association: name})
              end
            when FACTORY_SENTINEL
              nil
            else
              other = plan.model(target)
              if other.nil?
                add(:error, "#{field}.#{name}", "#{name} points at \"#{target}\", which is not a let in this plan.", "pick one of: #{plan.models.map(&:let).join(", ")}", {association: name})
              elsif !candidate_lets(model, assoc).include?(target)
                add(:error, "#{field}.#{name}", "#{name} expects a #{assoc.class_name}, but \"#{target}\" is a #{catalogue.factory(other.factory)&.class_name}.", "pick a let of class #{assoc.class_name}", {association: name})
              end
            end
          end
          assocs.each do |assoc|
            next if model.associations.key?(assoc.name)
            candidates = candidate_lets(model, assoc)
            if candidates.size > 1
              add(:warning, "#{field}.#{assoc.name}", "Several lets could be #{assoc.name}: #{candidates.join(", ")}. The factory will build its own.", "pick one", {association: assoc.name, candidates: candidates})
            elsif candidates.empty?
              parent_let = assoc.class_name.to_s.demodulize.underscore
              add(:warning, "#{field}.#{assoc.name}", "Missing parent: no let of class #{assoc.class_name || "(polymorphic)"} for #{assoc.name}; the factory will build one that no let refers to.",
                assoc.class_name ? "add let!(:#{parent_let}) { create(:#{parent_let}) }" : "add a let for it",
                {association: assoc.name, add_model: ((assoc.class_name && catalogue.factories.find { |f| f.class_name == assoc.class_name }) ? {"let" => parent_let, "factory" => catalogue.factories.find { |f| f.class_name == assoc.class_name }.name} : nil)})
            end
          end
        end
      end

      def check_signed_in
        return if plan.guest?
        model = plan.signed_in_model
        return add(:error, "signed_in", "\"#{plan.signed_in}\" is not one of the lets.", "add it to the models or pick guest") unless model
        klass = catalogue.factory(model.factory)&.class_name
        add(:error, "signed_in", "#{klass} cannot sign in: it has no user.", "pick a role model (#{catalogue.roles.map(&:class_name).join(", ")})") unless klass && catalogue.role(klass)
      end

      def check_start
        route = plan.start.route.to_s
        return add(:error, "start.route", "Choose a start page.", "e.g. #{catalogue.routes_for_role(signed_in_class).first&.name}") if route.empty?
        r = catalogue.route(route)
        return add(:error, "start.route", "No route called #{route}.", "pick one of the named GET routes") unless r
        r.params.each do |part|
          value = plan.start.params[part]
          if value.blank?
            add(:error, "start.params.#{part}", "#{r.name}_path needs :#{part}.", "map it to a let (e.g. #{part.sub(/_id\z/, "")})")
          elsif value !~ /\A\d+\z/ && !plan.model(value)
            add(:error, "start.params.#{part}", "\"#{value}\" is not a let in this plan.", "pick one of: #{plan.models.map(&:let).join(", ")}")
          end
        end
        preferred = catalogue.preferred_namespaces(signed_in_class)
        unless preferred.include?(r.namespace) || r.namespace == "public"
          add(:warning, "start.route", "#{r.name} is a #{r.namespace} page; the signed-in role is #{signed_in_class || "guest"}.", "expect a 403 or a redirect unless that role may see it")
        end
        add(:error, "start.locale", "Unknown locale #{plan.start.locale}.", "one of: #{I18n.available_locales.join(", ")}") unless I18n.available_locales.map(&:to_s).include?(plan.start.locale.to_s)
      end

      def check_extras
        ex = plan.extras
        if ex.travel_to
          begin
            Time.zone.parse(ex.travel_to) or raise ArgumentError
          rescue ArgumentError, TypeError
            add(:error, "extras.travel_to", "\"#{ex.travel_to}\" is not a date/time.", "e.g. 2026-12-24 10:00")
          end
        end
        if ex.viewport && ex.viewport_size.nil?
          add(:error, "extras.viewport", "Unknown viewport #{ex.viewport}.", "one of: #{Plan::Extras::VIEWPORTS.keys.join(", ")} or [width, height]")
        end
        ex.flags.each do |flag|
          add(:error, "extras.flags", "A flag needs a name.", "e.g. beta_dashboard") if flag["name"].to_s.empty?
          if flag["actor"].present? && !plan.model(flag["actor"])
            add(:error, "extras.flags", "Flag #{flag["name"]}: actor \"#{flag["actor"]}\" is not a let.", "pick a role let")
          end
          if flag["name"].present? && catalogue.flags.none? { |f| f.name == flag["name"].to_s }
            add(:warning, "extras.flags", "No code checks Flipper flag :#{flag["name"]}.", "known flags: #{catalogue.flags.map(&:name).join(", ").presence || "none"}")
          end
        end
        ex.fixture_files.each do |f|
          add(:error, "extras.fixture_files", "No fixture file #{f} in #{MagicTest.config.fixture_files_dir}.", "known: #{catalogue.fixture_files.join(", ").presence || "none"}") unless catalogue.fixture_files.include?(f)
        end
        add(:warning, "extras.sidekiq_inline", "Sidekiq::Testing is not loaded; the inline block will not work.", "require 'sidekiq/testing' in rails_helper") if ex.sidekiq_inline && !defined?(Sidekiq::Testing)
        add(:warning, "extras.flags", "Flipper is not loaded.", "add the flipper gem") if ex.flags.any? && !defined?(Flipper)
      end

      def check_order
        Ordering.order(plan.models)
      rescue Ordering::CycleError => e
        add(:error, "models", e.message, "break the cycle: let the factory build one side")
      end

      def signed_in_class
        model = plan.signed_in_model
        model && catalogue.factory(model.factory)&.class_name
      end
    end

    # Topological order of lets by their association references.
    module Ordering
      class CycleError < MagicTest::Error; end

      module_function

      def order(models)
        by_let = models.to_h { |m| [m.let, m] }
        deps = models.to_h { |m| [m.let, m.associations.values.compact.select { |v| by_let.key?(v) && v != m.let }.uniq] }
        ordered = []
        state = {}
        visit = lambda do |let, stack|
          case state[let]
          when :done then return
          when :visiting then raise CycleError, "Circular associations: #{(stack + [let]).join(" -> ")}."
          end
          state[let] = :visiting
          deps[let].each { |d| visit.call(d, stack + [let]) }
          state[let] = :done
          ordered << by_let[let]
        end
        models.each { |m| visit.call(m.let, []) }
        ordered
      end
    end
  end
end
