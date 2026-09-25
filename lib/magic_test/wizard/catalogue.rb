module MagicTest
  module Wizard
    # Everything the wizard can offer, introspected from the running app at
    # catalogue time: role classes, FactoryBot factories with their traits and
    # `belongs_to` reflections, named GET routes, existing system specs,
    # Flipper flags, fixture files and model columns. Nothing is hardcoded.
    class Catalogue
      Factory = Struct.new(:name, :class_name, :traits, :aliases) do
        def to_h
          {name: name, class_name: class_name, traits: traits, aliases: aliases}
        end
      end
      Association = Struct.new(:name, :class_name, :polymorphic, :optional, :foreign_key, :null) do
        def required?
          !optional && !null
        end

        def to_h
          {name: name, class_name: class_name, polymorphic: polymorphic, optional: optional, foreign_key: foreign_key, null: null}
        end
      end
      Route = Struct.new(:name, :path, :params, :namespace, :localized, :controller) do
        def to_h
          {name: name, path: path, params: params, namespace: namespace, localized: localized, controller: controller}
        end
      end
      Role = Struct.new(:class_name, :factory, :label) do
        def to_h
          {class_name: class_name, factory: factory, label: label}
        end
      end
      Flag = Struct.new(:name, :on_by_default, :source) do
        def to_h
          {name: name, on_by_default: on_by_default, source: source}
        end
      end

      ROLE_NAMESPACE_PREFIXES = {
        "provider" => %w[provider], "institution" => %w[institution], "student_organisation" => %w[student_organisation],
        "backoffice" => %w[backoffice admin], "company" => %w[company], "live_support" => %w[live_support], "api" => %w[api]
      }.freeze
      GUEST = "guest".freeze

      class << self
        def current
          @current ||= build
        end

        def reset!
          @current = nil
        end

        def build(root: Rails.root)
          new(root: root).tap(&:load!)
        end
      end

      attr_reader :root

      def initialize(root:)
        @root = Pathname(root.to_s)
      end

      def load!
        MagicTest::DbChanges.eager_load!
        @factories = load_factories
        @roles = load_roles
        @routes = load_routes
        @files = load_files
        @flags = load_flags
        @fixture_files = load_fixture_files
        self
      end

      attr_reader :factories, :roles, :routes, :files, :flags, :fixture_files

      def factory(name)
        name = name.to_s
        factories.find { |f| f.name == name || f.aliases.include?(name) }
      end

      def role(class_name)
        roles.find { |r| r.class_name == class_name.to_s }
      end

      def route(name)
        name = name.to_s
        routes.find { |r| r.name == name }
      end

      # Routes for the picker: the role's own namespace first, then public, then the rest.
      def routes_for_role(role_class_name)
        preferred = preferred_namespaces(role_class_name)
        routes.sort_by { |r| [preferred.index(r.namespace) || ((r.namespace == "public") ? preferred.size : preferred.size + 1), r.name] }
      end

      def preferred_namespaces(role_class_name)
        return ["public"] if role_class_name.nil? || role_class_name == GUEST
        key = role_class_name.to_s.demodulize.underscore
        key = "backoffice" if %w[admin team_member].include?(key)
        [ROLE_NAMESPACE_PREFIXES.key?(key) ? key : "public"]
      end

      # Model class for a factory (constantized lazily; nil when it does not resolve).
      def klass_for(factory_name)
        factory(factory_name)&.class_name&.safe_constantize
      end

      # `belongs_to` reflections of the factory's class, with NOT NULL info.
      def associations_for(factory_name)
        klass = klass_for(factory_name)
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        klass.reflect_on_all_associations(:belongs_to).map do |ref|
          column = klass.columns_hash[ref.foreign_key.to_s]
          Association.new(
            name: ref.name.to_s, class_name: (ref.polymorphic? ? nil : safe_class_name(ref)), polymorphic: ref.polymorphic?,
            optional: ref.options[:optional] == true || (ref.options.key?(:required) && ref.options[:required] == false),
            foreign_key: ref.foreign_key.to_s, null: column.nil? || column.null
          )
        end
      end

      # Settable attributes for the overrides picker: columns plus enum mappings.
      def attributes_for(factory_name)
        klass = klass_for(factory_name)
        return {} unless klass.respond_to?(:columns_hash)
        enums = klass.respond_to?(:defined_enums) ? klass.defined_enums : {}
        klass.columns_hash.each_with_object({}) do |(name, col), h|
          next if %w[id created_at updated_at].include?(name)
          h[name] = {type: col.type.to_s, null: col.null, enum: enums[name]&.keys}
        end
      end

      def attribute_settable?(factory_name, attribute)
        klass = klass_for(factory_name)
        return false unless klass
        attributes_for(factory_name).key?(attribute.to_s) || klass.method_defined?("#{attribute}=")
      end

      def to_h
        {
          factories: factories.map(&:to_h), roles: roles.map(&:to_h), routes: routes.map(&:to_h), files: files,
          flags: flags.map(&:to_h), fixture_files: fixture_files,
          associations: factories.to_h { |f| [f.name, associations_for(f.name).map(&:to_h)] },
          attributes: factories.to_h { |f| [f.name, attributes_for(f.name)] }
        }
      end

      private

      def safe_class_name(ref)
        ref.klass.name
      rescue NameError
        ref.class_name
      end

      def load_factories
        return [] unless defined?(FactoryBot)
        FactoryBot.reload if FactoryBot.factories.none? && FactoryBot.respond_to?(:reload)
        FactoryBot.factories.map do |f|
          traits = f.defined_traits.map { |t| t.name.to_s }
          parent = f.send(:parent) if f.respond_to?(:parent, true)
          traits += parent.defined_traits.map { |t| t.name.to_s } if parent.respond_to?(:defined_traits)
          Factory.new(name: f.name.to_s, class_name: begin
            f.build_class.name
          rescue
            f.name.to_s.camelize
          end, traits: traits.uniq.sort, aliases: (f.names - [f.name]).map(&:to_s))
        end.sort_by(&:name)
      end

      # Role classes: models with `has_one :user, as: :role`, models that define
      # their own `user` (Institution → leader's user), and anything named in
      # MagicTest.config.user_for_role.
      def load_roles
        return [] unless defined?(ActiveRecord::Base)
        classes = ActiveRecord::Base.descendants.reject { |k| k.abstract_class? || k.name.nil? || k.name.start_with?("HABTM_") }
        role_classes = classes.select do |k|
          k.reflect_on_all_associations(:has_one).any? { |r| r.options[:as].to_s == "role" && r.name.to_s == "user" } ||
            (k.method_defined?(:user, false) && !k.reflect_on_association(:user))
        end
        names = (role_classes.map(&:name) + MagicTest.config.user_for_role.keys.map(&:to_s)).uniq.sort
        names.map do |class_name|
          klass = class_name.safe_constantize
          factory = factories.find { |f| f.class_name == class_name && f.name == class_name.underscore.tr("/", "_") } ||
            factories.find { |f| f.class_name == class_name }
          Role.new(class_name: class_name, factory: factory&.name, label: klass.respond_to?(:model_name) ? klass.model_name.human : class_name)
        end.select(&:factory)
      end

      def load_routes
        all = Rails.application.routes.routes.select { |r| r.name.present? && r.verb.to_s.include?("GET") }
        grouped = Hash.new { |h, k| h[k] = {} }
        all.each do |r|
          base, locale = split_locale(r.name)
          grouped[base][locale] = r
        end
        grouped.map do |base, by_locale|
          route = by_locale[nil] || by_locale["da"] || by_locale.values.first
          path = route.path.spec.to_s.sub("(.:format)", "")
          Route.new(name: base, path: path, params: route.required_parts.map(&:to_s), namespace: namespace_for(base),
            localized: by_locale.key?("da") || by_locale.key?("en"), controller: route.defaults[:controller].to_s)
        end.reject { |r| r.name.start_with?("rails_", "magic_test", "action_mailbox", "active_storage") || r.path.start_with?("/__magic_test", "/rails/") }
          .sort_by(&:name)
      end

      def split_locale(name)
        locales = I18n.available_locales.map(&:to_s)
        m = name.match(/\A(.+)_(#{locales.map { |l| Regexp.escape(l) }.join("|")})\z/)
        m ? [m[1], m[2]] : [name, nil]
      end

      def namespace_for(name)
        ROLE_NAMESPACE_PREFIXES.each do |ns, prefixes|
          return ns if prefixes.any? { |p| name == p || name.start_with?("#{p}_") }
        end
        "public"
      end

      def load_files
        Dir[root.join("spec/system/**/*_spec.rb").to_s].map { |f| Pathname(f).relative_path_from(root).to_s }.sort
      end

      def load_flags
        flags = {}
        if defined?(Flipper)
          begin
            Flipper.features.each { |f|
              flags[f.key.to_s] = Flag.new(name: f.key.to_s, on_by_default: begin
                f.enabled?
              rescue
                false
              end, source: "Flipper.features")
            }
          rescue => e
            MagicTest.logger.warn("magic_test: Flipper.features failed: #{e.message}")
          end
        end
        pattern = /Flipper\.enabled\?\(\s*[:"']([A-Za-z0-9_]+)/
        (Dir[root.join("app/**/*.rb").to_s] + Dir[root.join("app/views/**/*").to_s]).each do |file|
          next unless File.file?(file)
          File.read(file).scan(pattern).flatten.each do |name|
            flags[name] ||= Flag.new(name: name, on_by_default: false, source: Pathname(file).relative_path_from(root).to_s)
          end
        rescue => e
          MagicTest.logger.warn("magic_test: flag scan failed for #{file}: #{e.message}")
        end
        flags.values.sort_by(&:name)
      end

      def load_fixture_files
        Dir[root.join(MagicTest.config.fixture_files_dir, "*").to_s].select { |f| File.file?(f) }.map { |f| File.basename(f) }.sort
      end
    end
  end
end
