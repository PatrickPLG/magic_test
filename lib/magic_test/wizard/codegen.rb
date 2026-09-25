require "magic_test/ruby_literal"

module MagicTest
  module Wizard
    # Turns a validated Plan into the spec skeleton: ordered `let!`s, a
    # `before` (driver, flags, time, viewport, cookies, sign-in) and an `it`
    # that visits the start page and ends in `magic_test`. Writes a new file
    # in Studiz house style, or an insertion into an existing describe/context
    # (reusing its lets, renaming on collision, adding a context when the
    # example needs setup the block does not have).
    class Codegen
      Skeleton = Struct.new(:mode, :lets, :before_lines, :it_lines, :body_lines, :source, :insert_before_line, :renames, :reused, :names, :user_expression, :context_description) do
        def to_h
          {mode: mode, lets: lets, before_lines: before_lines, it_lines: it_lines, source: source, renames: renames, reused: reused, names: names, user_expression: user_expression, context_description: context_description}
        end
      end

      attr_reader :plan, :catalogue, :spec_file, :block

      def initialize(plan, catalogue, spec_file: nil, block: nil)
        @plan = plan
        @catalogue = catalogue
        @spec_file = spec_file
        @block = block || spec_file&.find_block(plan.target.block)
      end

      def self.build(plan, catalogue, spec_file: nil, block: nil)
        new(plan, catalogue, spec_file: spec_file, block: block).skeleton
      end

      # The emitted name for a plan let (after collision renames).
      def name_for(let)
        names[let.to_s] || let.to_s
      end

      def names
        @names ||= compute_names
      end

      def reused
        names
        @reused
      end

      def renames
        names
        @renames
      end

      def user_expression
        model = plan.signed_in_model or return nil
        MagicTest.config.user_expression(catalogue.factory(model.factory)&.class_name, name_for(model.let))
      end

      def let_lines
        let_entries.map { |name, expr| "let!(:#{name}) { #{expr} }" }
      end

      # [[emitted name, create expression]] in dependency order, reused lets left out.
      def let_entries
        Ordering.order(plan.models).reject { |m| reused.key?(m.let) }.map { |m| [name_for(m.let), let_expression(m)] }
      end

      def let_line(model)
        "let!(:#{name_for(model.let)}) { #{let_expression(model)} }"
      end

      def let_expression(model)
        args = [":#{model.factory}"] + model.traits.map { |t| ":#{t}" }
        args << model.count.to_s if model.count > 1
        kwargs = []
        model.associations.each do |assoc, target|
          case target
          when nil, Validator::FACTORY_SENTINEL then next
          when Validator::NONE_SENTINEL then kwargs << "#{assoc}: nil"
          else kwargs << "#{assoc}: #{name_for(target)}"
          end
        end
        model.attributes.each { |k, v| kwargs << "#{k}: #{RubyLiteral.value(v)}" }
        call = (model.count > 1) ? "create_list" : "create"
        "#{call}(#{(args + kwargs).join(", ")})"
      end

      # Everything the `before` needs except the driver line.
      def setup_lines
        ex = plan.extras
        lines = []
        ex.flags.each do |flag|
          name = RubyLiteral.symbol(flag["name"])
          if flag["actor"].present?
            actor = flag_actor_expression(flag["actor"])
            lines << (flipper_enable_actor? ? "Flipper.enable_actor(#{name}, #{actor})" : "Flipper.enable(#{name}, #{actor})")
          else
            lines << "Flipper.enable(#{name})"
          end
        end
        lines << "travel_to(Time.zone.parse(#{RubyLiteral.string(ex.travel_to)}))" if ex.travel_to
        size = ex.viewport_size
        lines << "page.driver.resize(#{size[0]}, #{size[1]})" if size && size != MagicTest.config.window_size
        lines << "page.driver.set_cookie('cookie_settings', 'necessary')" if plan.guest? && ex.cookie_consent
        lines << "ActionMailer::Base.deliveries.clear" if ex.mail_assertion
        lines << "magic_sign_in(#{user_expression})" if !plan.guest? && !sign_in_covered?
        lines
      end

      def before_lines
        driver = MagicTest.config.wizard_driven_by.presence
        (driver && mode != :append_it) ? [driver] + setup_lines : setup_lines
      end

      def it_lines
        inner = ["visit(#{start_expression})", "magic_test"]
        if plan.extras.sidekiq_inline
          ["Sidekiq::Testing.inline! do"] + inner.map { |l| "  #{l}" } + ["end"]
        else
          inner
        end
      end

      def start_expression
        route = catalogue.route(plan.start.route) or return "root_path"
        helper = (route.localized && plan.start.locale.to_s != I18n.default_locale.to_s) ? "#{route.name}_#{plan.start.locale}_path" : "#{route.name}_path"
        args = route.params.map do |part|
          value = plan.start.params[part]
          value.to_s.match?(/\A\d+\z/) ? value.to_s : name_for(value)
        end
        args.empty? ? helper : "#{helper}(#{args.join(", ")})"
      end

      # :new_file, :append_it (everything already there) or :new_context.
      def mode
        return :new_file unless spec_file && block
        return :append_it if let_lines.empty? && setup_lines.empty?
        :new_context
      end

      def context_description
        model_names = plan.models.reject { |m| reused.key?(m.let) }.map { |m| name_for(m.let).tr("_", " ") }
        return "when signed in as #{role_word}" if !plan.guest? && !sign_in_covered? && model_names.include?(name_for(plan.signed_in).tr("_", " "))
        return "with #{model_names.to_sentence(locale: :en)}" if model_names.any?
        (!plan.guest? && !sign_in_covered?) ? "when signed in as #{role_word}" : "with #{plan.description}"
      end

      def skeleton
        body = example_lines
        case mode
        when :new_file
          src = new_file_source
          Skeleton.new(mode: :new_file, lets: let_lines, before_lines: before_lines, it_lines: it_lines, body_lines: body, source: src, insert_before_line: nil,
            renames: renames, reused: reused, names: names, user_expression: user_expression, context_description: nil)
        when :append_it
          _, line = spec_file.insertion_for(block, body)
          Skeleton.new(mode: :append_it, lets: [], before_lines: [], it_lines: it_lines, body_lines: body, source: spec_file.content_with(block, body), insert_before_line: line,
            renames: renames, reused: reused, names: names, user_expression: user_expression, context_description: nil)
        else
          ctx = ["context #{RubyLiteral.string(context_description)} do"] + indent(let_lines) + (let_lines.any? ? [""] : []) +
            indent(before_block) + [""] + indent(body) + ["end"]
          _, line = spec_file.insertion_for(block, ctx)
          Skeleton.new(mode: :new_context, lets: let_lines, before_lines: before_lines, it_lines: it_lines, body_lines: ctx, source: spec_file.content_with(block, ctx), insert_before_line: line,
            renames: renames, reused: reused, names: names, user_expression: user_expression, context_description: context_description)
        end
      end

      # The `it` block as unindented lines.
      def example_lines
        ["it #{RubyLiteral.string(plan.description)} do"] + indent(it_lines) + ["end"]
      end

      def before_block
        return [] if before_lines.empty?
        ["before do"] + indent(before_lines) + ["end"]
      end

      def new_file_source
        lines = ["require 'rails_helper'", "", "# #{plan.description}", "RSpec.describe(#{RubyLiteral.string(plan.description.sub(/\A[a-z]/, &:upcase))}, :js, type: :system) do"]
        lines += indent(let_lines)
        lines << "" if let_lines.any?
        lines += indent(before_block)
        lines << "" if before_lines.any?
        lines += indent(example_lines)
        lines << "end"
        lines.map { |l| l.empty? ? "\n" : "#{l}\n" }.join
      end

      private

      def indent(lines)
        lines.map { |l| l.empty? ? "" : "  #{l}" }
      end

      def role_word
        model = plan.signed_in_model
        klass = model && catalogue.factory(model.factory)&.class_name
        klass ? klass.demodulize.underscore.humanize.downcase.then { |w| "a #{w}" } : "a user"
      end

      def flag_actor_expression(let)
        model = plan.model(let)
        klass = model && catalogue.factory(model.factory)&.class_name
        (klass && catalogue.role(klass)) ? MagicTest.config.user_expression(klass, name_for(let)) : name_for(let)
      end

      def flipper_enable_actor?
        defined?(Flipper) && Flipper.respond_to?(:enable_actor)
      end

      # An existing before in the block chain already signs in our role let.
      def sign_in_covered?
        return false unless block && !plan.guest?
        wanted = name_for(plan.signed_in)
        block.visible_sign_ins.any? { |s| s.let_name == wanted && (s.role_hint.nil? || reused.key?(plan.signed_in) || true) }
      end

      # Reuse existing lets with the same name, factory and traits; rename
      # ours when the name is taken by something else.
      def compute_names
        @reused = {}
        @renames = {}
        names = plan.models.to_h { |m| [m.let, m.let] }
        return names unless block
        existing = block.visible_lets.to_h { |l| [l.name, l] }
        taken = existing.keys.to_set
        plan.models.each do |model|
          ex = existing[model.let]
          next unless ex
          if ex.factory == model.factory && ex.traits.sort == model.traits.sort && model.count == 1
            @reused[model.let] = ex
          else
            candidate = model.traits.any? ? "#{model.traits.first}_#{model.let}" : "#{model.let}_2"
            n = 2
            while taken.include?(candidate) || names.value?(candidate)
              n += 1
              candidate = "#{model.let}_#{n}"
            end
            names[model.let] = candidate
            @renames[model.let] = candidate
            taken << candidate
          end
        end
        names
      end
    end
  end
end
