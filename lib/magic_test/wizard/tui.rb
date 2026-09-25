require "magic_test/wizard"

module MagicTest
  module Wizard
    # The terminal front end: the same questions as the browser wizard, on a
    # dependency-free prompt layer (numbered lists that also accept a filter
    # string). Reads from `input` and writes to `output`, so specs can drive
    # it with a StringIO.
    class TUI
      class Abort < Wizard::Error; end

      attr_reader :runner, :catalogue, :input, :output

      def initialize(runner, input: $stdin, output: $stdout)
        @runner = runner
        @catalogue = runner.catalogue
        @input = input
        @output = output
      end

      def run
        say "magic_test #{MagicTest::VERSION} — new system test"
        plan = collect(Plan.new)
        codegen = nil
        loop do
          validator = runner.validate(plan)
          if validator.warnings.any?
            say "Warnings:"
            validator.warnings.each { |i| say "  - #{i.field}: #{i.message}#{"  (fix: #{i.fix})" if i.fix}" }
          end
          if validator.errors.any?
            say "The plan is not valid:"
            validator.errors.each { |i| say "  - #{i.field}: #{i.message}#{"  (fix: #{i.fix})" if i.fix}" }
            raise Abort, "aborted" unless yes?("Edit the plan?", default: true)
            plan = collect(plan)
            next
          end
          codegen = runner.codegen_for(plan)
          skeleton = codegen.skeleton
          say "\nSkeleton (#{skeleton.mode}) for #{runner.path_for(plan)}:"
          say skeleton.body_lines.map { |l| "    #{l}" }.join("\n")
          say "  signed in as: #{skeleton.user_expression}" if skeleton.user_expression
          unless yes?("Run preflight?", default: true)
            raise Abort, "aborted" unless yes?("Edit the plan?", default: true)
            plan = collect(plan)
            next
          end
          result = runner.preflight(codegen)
          say result.summary
          result.notes.each { |n| say "  note: #{n}" }
          break if result.ok
          raise Abort, "preflight failed; nothing was written" unless yes?("Edit the plan and run preflight again?", default: true)
          plan = collect(plan)
        end
        raise Abort, "nothing was written" unless yes?("Write the skeleton and start recording?", default: true)
        runner.record(runner.write(codegen), plan)
      end

      # ---- questions -------------------------------------------------------

      def collect(plan)
        plan.description = ask("Describe the test (becomes the `it` name)", default: plan.description.presence)
        collect_target(plan)
        collect_role(plan)
        collect_models(plan)
        collect_start(plan)
        collect_extras(plan)
        plan
      end

      def collect_target(plan)
        suggested = plan.target.path.presence || ENV["MAGIC_TEST_WIZARD_TARGET"].presence
        files = catalogue.files
        options = files + ["new file"]
        default = (suggested && files.include?(suggested)) ? suggested : "new file"
        choice = choose("Spec file", options, default: default)
        if choice == "new file"
          role_class = plan.signed_in_model && catalogue.factory(plan.signed_in_model.factory)&.class_name
          proposed = (suggested && !files.include?(suggested)) ? suggested : Wizard.suggest_path(role_class, plan.description)
          plan.target = Plan::Target.new(path: ask("Path for the new file", default: proposed), block: nil)
        else
          file = SpecFile.parse(runner.path_for(Plan::Target.new(path: choice, block: nil)))
          blocks = file.all_blocks
          block = (blocks.size > 1) ? choose("Which describe/context block", blocks.map { |b| b.path.join(" > ") }, default: blocks.first.path.join(" > ")) : blocks.first.path.join(" > ")
          plan.target = Plan::Target.new(path: choice, block: blocks.find { |b| b.path.join(" > ") == block }&.path&.last(1))
        end
      end

      def collect_role(plan)
        roles = ["guest / not signed in"] + catalogue.roles.map { |r| "#{r.class_name} (create(:#{r.factory}))" }
        current = plan.signed_in_model && catalogue.factory(plan.signed_in_model.factory)&.class_name
        default = current ? roles.find { |r| r.start_with?("#{current} (") } : roles.first
        choice = choose("Signed-in role", roles, default: default)
        if choice == roles.first
          plan.models.delete_if { |m| m.let == plan.signed_in } if plan.signed_in
          plan.signed_in = nil
          return
        end
        role = catalogue.roles[roles.index(choice) - 1]
        factory = catalogue.factory(role.factory)
        let = ask("Name of the let", default: plan.signed_in || role.factory.split("_").last)
        existing = plan.model(plan.signed_in) if plan.signed_in
        plan.models.delete(existing) if existing
        traits = multi("Traits for :#{factory.name}", factory.traits, default: existing&.traits || [])
        plan.models.unshift(Plan::Model.new(let: let, factory: factory.name, traits: traits))
        plan.signed_in = let
      end

      def collect_models(plan)
        others = plan.models.reject { |m| m.let == plan.signed_in }
        others.each { |m| say "  model: let!(:#{m.let}) { create(:#{m.factory}#{m.traits.map { |t| ", :#{t}" }.join}) }" }
        if others.any? && !yes?("Keep these models?", default: true)
          plan.models.delete_if { |m| m.let != plan.signed_in }
        end
        loop do
          name = ask("Add a model (factory name, blank to continue)", default: nil, allow_blank: true)
          break if name.blank?
          matches = catalogue.factories.select { |f| f.name.include?(name) || f.aliases.any? { |a| a.include?(name) } }
          factory = if matches.size == 1
            matches.first
          elsif matches.empty?
            say "  no factory matches #{name.inspect}"
            next
          else
            catalogue.factory(choose("Which factory", matches.map(&:name), default: matches.first.name))
          end
          let = ask("Name of the let", default: factory.name.split("_").last)
          traits = multi("Traits for :#{factory.name}", factory.traits, default: [])
          count = ask("How many (create_list when > 1)", default: "1").to_i
          model = Plan::Model.new(let: let, factory: factory.name, traits: traits, count: count)
          plan.models << model
          Validator.new(plan, catalogue).auto_wire!
          catalogue.associations_for(factory.name).each do |assoc|
            candidates = plan.models.reject { |m| m.let == let }.map(&:let)
            options = candidates + ["let the factory build it", "none (nil)"]
            current = model.associations[assoc.name]
            default = if current.nil?
              "let the factory build it"
            else
              ((current == "none") ? "none (nil)" : current)
            end
            choice = choose("#{let}.#{assoc.name} (#{assoc.class_name || "polymorphic"}#{", required" if assoc.required?})", options, default: default)
            model.associations[assoc.name] = case choice
            when "let the factory build it" then Validator::FACTORY_SENTINEL
            when "none (nil)" then Validator::NONE_SENTINEL
            else choice
            end
          end
          loop do
            pair = ask("Attribute override (name=value, blank to continue)", default: nil, allow_blank: true)
            break if pair.blank?
            k, v = pair.split("=", 2)
            model.attributes[k.to_s.strip] = v.to_s.strip
          end
        end
      end

      def collect_start(plan)
        role_class = plan.signed_in_model && catalogue.factory(plan.signed_in_model.factory)&.class_name
        routes = catalogue.routes_for_role(role_class)
        labels = routes.map { |r| "#{r.name}_path  #{r.path}" }
        default = plan.start.route.presence ? labels.find { |l| l.start_with?("#{plan.start.route}_path ") } : labels.first
        choice = choose("Start page", labels, default: default)
        route = routes[labels.index(choice)]
        params = {}
        route.params.each do |part|
          lets = plan.models.map(&:let)
          guess = plan.start.params[part] || lets.find { |l| part == "#{l}_id" || (part == "id" && lets.last == l) } || lets.last
          params[part] = lets.any? ? choose("Value for :#{part}", lets, default: guess) : ask("Value for :#{part}")
        end
        locale = (route.localized && I18n.available_locales.size > 1) ? choose("Locale", I18n.available_locales.map(&:to_s), default: plan.start.locale) : I18n.default_locale.to_s
        plan.start = Plan::Start.new(route: route.name, params: params, locale: locale)
      end

      def collect_extras(plan)
        ex = plan.extras
        if catalogue.flags.any?
          labels = catalogue.flags.map { |f| "#{f.name}#{" (on by default)" if f.on_by_default}" }
          chosen = multi("Flipper flags to enable", labels, default: ex.flags.map { |f| f["name"] })
          ex.flags = chosen.map do |label|
            name = label.sub(/ \(on by default\)\z/, "")
            actor_options = ["globally"] + plan.models.map(&:let)
            existing = ex.flags.find { |f| f["name"] == name }
            actor = choose("Enable #{name}", actor_options, default: existing&.dig("actor") || (plan.signed_in || "globally"))
            (actor == "globally") ? {"name" => name} : {"name" => name, "actor" => actor}
          end
        end
        ex.travel_to = ask("Freeze time at (blank for no)", default: ex.travel_to, allow_blank: true).presence
        ex.viewport = choose("Viewport", Plan::Extras::VIEWPORTS.keys, default: ex.viewport || "desktop")
        ex.viewport = nil if ex.viewport == "desktop"
        ex.cookie_consent = yes?("Set the cookie consent cookie?", default: ex.cookie_consent) if plan.guest?
        ex.sidekiq_inline = yes?("Run Sidekiq jobs inline for this test?", default: ex.sidekiq_inline) if defined?(Sidekiq::Testing)
        ex.mail_assertion = yes?("Assert on emails sent during the test?", default: ex.mail_assertion)
        ex.fixture_files = multi("Fixture files the test will upload", catalogue.fixture_files, default: ex.fixture_files) if catalogue.fixture_files.any?
        say "  note: a new student gets the onboarding modal; the recorder captures its dismissal (Senere)." if role_is_student?(plan)
      end

      def role_is_student?(plan)
        model = plan.signed_in_model
        model && catalogue.factory(model.factory)&.class_name == "Student"
      end

      # ---- prompt layer ----------------------------------------------------

      def say(text)
        output.puts(text)
        output.flush if output.respond_to?(:flush)
      end

      def ask(label, default: nil, allow_blank: false)
        loop do
          output.print("#{label}#{" [#{default}]" if default}: ")
          output.flush if output.respond_to?(:flush)
          line = input.gets
          raise Abort, "input closed" if line.nil?
          line = line.chomp.strip
          return default.to_s if line.empty? && default
          return line if !line.empty? || allow_blank
          say "  (an answer is needed)"
        end
      end

      # A numbered list; the answer is a number, an exact option, or a filter
      # that matches exactly one option.
      def choose(label, options, default: nil)
        say "#{label}:"
        options.each_with_index { |o, i| say "  #{i + 1}) #{o}" }
        loop do
          answer = ask("Choose", default: default, allow_blank: false)
          return options[answer.to_i - 1] if answer.match?(/\A\d+\z/) && options[answer.to_i - 1]
          return answer if options.include?(answer)
          by_token = options.select { |o| o.split(/\s+/).first == answer }
          return by_token.first if by_token.size == 1
          matches = options.select { |o| o.downcase.include?(answer.downcase) }
          return matches.first if matches.size == 1
          say matches.empty? ? "  nothing matches #{answer.inspect}" : "  several match: #{matches.first(5).join(", ")}"
        end
      end

      # Comma-separated numbers or names; blank keeps the default.
      def multi(label, options, default: [])
        return [] if options.empty?
        say "#{label} (comma-separated, blank for #{default.empty? ? "none" : default.join(", ")}):"
        options.each_with_index { |o, i| say "  #{i + 1}) #{o}" }
        answer = ask("Choose", default: nil, allow_blank: true)
        return default if answer.blank?
        return [] if answer.strip == "-"
        answer.split(",").map(&:strip).reject(&:empty?).filter_map do |token|
          next options[token.to_i - 1] if token.match?(/\A\d+\z/)
          options.find { |o| o == token } || options.find { |o| o.downcase.start_with?(token.downcase) }
        end.uniq
      end

      def yes?(label, default: true)
        answer = ask("#{label} (#{default ? "Y/n" : "y/N"})", default: nil, allow_blank: true)
        return default if answer.blank?
        answer.match?(/\Ay/i)
      end
    end
  end
end
