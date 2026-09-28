require "json"
require "digest"

module MagicTest
  module Wizard
    # Learns the host's own conventions from its specs (1.2 §4): which
    # factories and trait combinations `create`/`create_list`/`build` use, which
    # sign-in helper goes with which factory, and which start pages each role
    # visits. Parsed with RubyVM::AbstractSyntaxTree like SpecFile, never with
    # regexes; per-file results are cached in tmp/magic_test/catalogue_cache.json
    # keyed by the file's mtime, so only changed files are parsed again.
    class SpecScanner
      CACHE_PATH = "tmp/magic_test/catalogue_cache.json"
      CACHE_VERSION = 1
      BUILD_METHODS = %i[create create_list build build_stubbed].freeze
      GROUP_METHODS = %i[describe context feature xdescribe xcontext].freeze
      SIGN_IN_HELPER = /\Asign_in_as_([a-z_]+)\z/
      GUEST = "guest".freeze

      # What one file contributed; aggregated over all files into Learned.
      FileData = Struct.new(:factories, :sign_ins, :routes) do
        def self.empty
          new({}, {}, {})
        end
      end

      class Learned
        attr_reader :factories, :sign_ins, :routes, :files

        def initialize(factories: {}, sign_ins: {}, routes: {}, files: 0)
          @factories = factories # "provider" => {"count" => 12, "files" => 9, "combos" => {"with_cvr" => 8}, "kwargs" => {"name_da" => 3}, "methods" => {"create" => 11}}
          @sign_ins = sign_ins # "provider" (role key) => {"factories" => {"provider" => 9}, "traits" => {"with_cvr" => 8}, "count" => 9}
          @routes = routes # "provider" => {"provider_admin_discounts" => 7}, "guest" => {...}
          @files = files
        end

        def usage(factory)
          factories.dig(factory.to_s, "count").to_i
        end

        # The most common trait combination and how many spec files use it.
        def default_traits(factory)
          combos = factories.dig(factory.to_s, "combos") || {}
          return [[], 0] if combos.empty?
          combo, files = combos.max_by { |c, n| [n, -c.length] }
          [combo.split(",").reject(&:empty?), files]
        end

        # Trait combinations ordered by use ("with_cvr" => 8, "" => 1).
        def trait_combinations(factory)
          (factories.dig(factory.to_s, "combos") || {}).sort_by { |c, n| [-n, c] }.map { |c, n| [c.split(",").reject(&:empty?), n] }
        end

        def common_kwargs(factory)
          (factories.dig(factory.to_s, "kwargs") || {}).sort_by { |k, n| [-n, k] }.map(&:first)
        end

        # The factory (and traits) specs sign in with for a role key ("provider", "institution").
        def sign_in_for(role_key)
          data = sign_ins[role_key.to_s] or return nil
          factory = data["factories"].max_by { |_f, n| n }&.first or return nil
          traits = data["traits"].select { |_t, n| n * 2 > data["count"] }.keys # traits used in more than half of the sign-ins
          {"factory" => factory, "traits" => traits, "count" => data["count"]}
        end

        def route_visits(role_key)
          routes[role_key.to_s] || {}
        end

        def to_h
          {"factories" => factories, "sign_ins" => sign_ins, "routes" => routes, "files" => files}
        end
      end

      def self.scan(root, cache: true)
        new(root, cache: cache).scan
      end

      attr_reader :root

      def initialize(root, cache: true)
        @root = Pathname(root.to_s)
        @cache = cache
      end

      # The host's spec files. A nested fixture app's specs (this gem's own
      # layout) are not the host's conventions.
      def spec_files
        Dir[root.join("spec/**/*.rb").to_s].reject { |f| Pathname(f).relative_path_from(root).to_s.start_with?("spec/fixture_app/") }.sort
      end

      def scan
        cached = @cache ? read_cache : {}
        entries = {}
        files = spec_files
        files.each do |path|
          rel = Pathname(path).relative_path_from(root).to_s
          mtime = File.mtime(path).to_f
          entry = cached[rel]
          if entry && entry["mtime"] == mtime
            entries[rel] = entry
          else
            data = scan_file(path)
            entries[rel] = {"mtime" => mtime, "data" => data.to_h.transform_keys(&:to_s)}
          end
        end
        write_cache(entries) if @cache
        aggregate(entries.values.map { |e| e["data"] }, files.size)
      end

      # ---- one file ---------------------------------------------------------

      def scan_file(path)
        source = File.read(path)
        ast = RubyVM::AbstractSyntaxTree.parse(source)
        @data = FileData.empty
        @lets = {} # let name => [factory, traits]
        @frames = [{role: nil}]
        walk(ast)
        @data
      rescue SyntaxError, StandardError => e
        # A spec the walker does not understand never breaks the wizard: it just teaches nothing.
        MagicTest.logger.warn("magic_test wizard: could not learn from #{path}: #{e.class}: #{e.message}")
        FileData.empty
      end

      private

      def walk(node)
        return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
        case node.type
        when :ITER
          call = node.children[0]
          name = call_name(call)
          if GROUP_METHODS.include?(name)
            @frames.push({role: nil})
            node.children.each { |c| walk(c) }
            @frames.pop
            return
          end
          if %i[let let!].include?(name)
            let_name = args_of(call).find { |a| a.type == :LIT }&.children&.first
            body = node.children[1].children[2]
            build = find_build_call(body)
            @lets[let_name.to_s] = factory_and_traits(build) if let_name && build
          end
        when :FCALL, :CALL, :VCALL
          note_call(node)
        end
        node.children.each { |c| walk(c) }
      end

      def note_call(node)
        name = call_name(node)
        return unless name
        if BUILD_METHODS.include?(name)
          note_build(node, name)
        elsif (m = SIGN_IN_HELPER.match(name.to_s))
          note_sign_in(m[1], args_of(node).first)
        elsif %i[magic_sign_in sign_in login_as].include?(name)
          note_sign_in(nil, args_of(node).first)
        elsif name == :visit
          note_visit(args_of(node).first)
        end
      end

      def note_build(node, method)
        factory, traits, kwargs = factory_and_traits(node, with_kwargs: true)
        return unless factory
        f = (@data.factories[factory] ||= {"count" => 0, "combos" => {}, "kwargs" => {}, "methods" => {}})
        f["count"] += 1
        combo = traits.join(",") # as written: Studiz reads create(:institution, :with_user, :with_specialities)
        f["combos"][combo] = (f["combos"][combo] || 0) + 1
        kwargs.each { |k| f["kwargs"][k] = (f["kwargs"][k] || 0) + 1 }
        f["methods"][method.to_s] = (f["methods"][method.to_s] || 0) + 1
      end

      # sign_in_as_provider(provider) → role "provider"; magic_sign_in(provider.user) → the let's factory.
      def note_sign_in(role, arg)
        let_name = arg && source_head(arg)
        factory, traits = @lets[let_name.to_s]
        role ||= factory
        return unless role
        @frames.last[:role] = role
        s = (@data.sign_ins[role] ||= {"factories" => {}, "traits" => {}, "count" => 0})
        s["count"] += 1
        if factory
          s["factories"][factory] = (s["factories"][factory] || 0) + 1
          traits.each { |t| s["traits"][t] = (s["traits"][t] || 0) + 1 }
        end
      end

      def note_visit(arg)
        return unless arg.is_a?(RubyVM::AbstractSyntaxTree::Node)
        helper = call_name(arg)
        return unless helper&.to_s&.match?(/_(path|url)\z/)
        route = helper.to_s.sub(/_(path|url)\z/, "")
        role = @frames.reverse.map { |f| f[:role] }.compact.first || GUEST
        r = (@data.routes[role] ||= {})
        r[route] = (r[route] || 0) + 1
      end

      # ---- AST helpers ------------------------------------------------------

      def call_name(node)
        return nil unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
        case node.type
        when :FCALL, :VCALL then node.children[0]
        when :CALL then node.children[1]
        end
      end

      def args_of(node)
        return [] unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
        list = case node.type
        when :FCALL then node.children[1]
        when :CALL then node.children[2]
        end
        (list&.type == :LIST) ? list.children.compact : []
      end

      def find_build_call(node)
        return nil unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
        return node if %i[FCALL CALL].include?(node.type) && BUILD_METHODS.include?(call_name(node))
        node.children.each do |c|
          found = find_build_call(c)
          return found if found
        end
        nil
      end

      def factory_and_traits(call, with_kwargs: false)
        args = args_of(call)
        syms = args.select { |a| a.type == :LIT && a.children[0].is_a?(Symbol) }.map { |a| a.children[0].to_s }
        factory = syms.shift
        hash = args.find { |a| a.type == :HASH }
        kwargs = []
        hash&.children&.first&.children.to_a.compact.each_slice(2) { |k, _v| kwargs << k.children[0].to_s if k.type == :LIT } # HASH → LIST of key, value pairs
        with_kwargs ? [factory, syms, kwargs] : [factory, syms]
      end

      # `provider` from provider / provider.user / provider.employees.first.user
      def source_head(node)
        return nil unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
        case node.type
        when :VCALL, :LVAR then node.children[0].to_s
        when :CALL then source_head(node.children[0])
        when :FCALL then node.children[0].to_s
        end
      end

      # ---- cache + aggregate ------------------------------------------------

      def cache_path
        root.join(CACHE_PATH)
      end

      def read_cache
        return {} unless cache_path.exist?
        data = JSON.parse(cache_path.read)
        (data["version"] == CACHE_VERSION) ? (data["files"] || {}) : {}
      rescue JSON::ParserError
        {}
      end

      def write_cache(entries)
        FileUtils.mkdir_p(cache_path.dirname)
        cache_path.write(JSON.generate({"version" => CACHE_VERSION, "files" => entries}))
      rescue => e
        MagicTest.logger.warn("magic_test wizard: could not write #{cache_path}: #{e.message}")
      end

      def aggregate(datas, file_count)
        factories = {}
        sign_ins = {}
        routes = {}
        datas.each do |d|
          (d["factories"] || {}).each do |name, f|
            t = (factories[name] ||= {"count" => 0, "files" => 0, "combos" => {}, "kwargs" => {}, "methods" => {}})
            t["count"] += f["count"].to_i
            t["files"] += 1
            f["combos"].each { |c, _n| t["combos"][c] = (t["combos"][c] || 0) + 1 } # combos count files, not calls
            f["kwargs"].each { |k, n| t["kwargs"][k] = (t["kwargs"][k] || 0) + n }
            f["methods"].each { |k, n| t["methods"][k] = (t["methods"][k] || 0) + n }
          end
          (d["sign_ins"] || {}).each do |role, s|
            t = (sign_ins[role] ||= {"factories" => {}, "traits" => {}, "count" => 0})
            t["count"] += s["count"].to_i
            s["factories"].each { |k, n| t["factories"][k] = (t["factories"][k] || 0) + n }
            s["traits"].each { |k, n| t["traits"][k] = (t["traits"][k] || 0) + n }
          end
          (d["routes"] || {}).each do |role, r|
            t = (routes[role] ||= {})
            r.each { |k, n| t[k] = (t[k] || 0) + n }
          end
        end
        Learned.new(factories: factories, sign_ins: sign_ins, routes: routes, files: file_count)
      end
    end
  end
end
