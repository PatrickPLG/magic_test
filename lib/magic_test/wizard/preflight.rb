require "magic_test/ruby_literal"

module MagicTest
  module Wizard
    # Proves the plan's setup before anything is written: evaluates the lets
    # in order inside the real example (FactoryBot, DatabaseCleaner, Flipper
    # and travel_to behave exactly as in the spec), checks every record is
    # valid and persisted, resolves the sign-in user, signs in, visits the
    # start page and reports status, final URL, JS errors and a screenshot.
    # Every failure names its stage and a suggested fix.
    class Preflight
      Failure = Struct.new(:stage, :message, :fix, :field) do
        def to_h
          {stage: stage, message: message, fix: fix, field: field}
        end

        def to_s
          fix ? "#{message} (fix: #{fix})" : message
        end
      end

      Result = Struct.new(:ok, :failures, :status, :url, :path, :expected_path, :title, :js_errors, :screenshot, :records, :user, :notes) do
        def to_h
          {ok: ok, failures: failures.map(&:to_h), status: status, url: url, path: path, expected_path: expected_path, title: title,
           js_errors: js_errors, screenshot: screenshot, records: records, user: user, notes: notes}
        end

        def summary
          return "preflight passed: #{status} #{path} (#{records.size} record(s), signed in as #{user || "guest"})" if ok
          failures.map { |f| "preflight failed at #{f.stage}: #{f}" }.join("\n")
        end
      end

      attr_reader :codegen, :context, :plan, :catalogue, :records, :recording_window

      def initialize(codegen, context:)
        @codegen = codegen
        @context = context
        @plan = codegen.plan
        @catalogue = codegen.catalogue
        @records = {}
        @defined = []
      end

      # @param new_window [Boolean] open the start page in a second window
      #   (the browser wizard keeps its own page in the first one)
      def run(new_window: false)
        reset_state!
        failures = []
        notes = []
        evaluate_existing_lets(failures)
        evaluate_plan_lets(failures) if failures.empty?
        check_records(failures) if failures.empty?
        user = failures.empty? ? resolve_user(failures) : nil
        run_setup(failures, user) if failures.empty?
        page_info = failures.empty? ? visit(failures, notes, new_window: new_window) : {}
        install_memoized! if failures.empty?
        Result.new(failures.empty?, failures, page_info[:status], page_info[:url], page_info[:path], page_info[:expected_path], page_info[:title],
          page_info[:js_errors] || [], page_info[:screenshot], record_summary, user && describe_user(user), notes)
      end

      # Clean slate between attempts: data, time, memoised values, session.
      def reset_state!
        @defined.each { |name| context.singleton_class.send(:remove_method, name) if context.singleton_class.method_defined?(name) }
        @defined = []
        @records = {}
        context.travel_back if context.respond_to?(:travel_back)
        if defined?(DatabaseCleaner)
          DatabaseCleaner.clean_with(:truncation)
        elsif defined?(ActiveRecord::Base)
          conn = ActiveRecord::Base.connection
          (conn.tables - %w[schema_migrations ar_internal_metadata]).each { |t| conn.execute("DELETE FROM #{conn.quote_table_name(t)}") }
        end
        ActionMailer::Base.deliveries.clear if defined?(ActionMailer::Base)
        Sidekiq::Worker.clear_all if defined?(Sidekiq::Worker) && Sidekiq::Worker.respond_to?(:clear_all)
        begin
          context.page.driver.clear_cookies if context.page.driver.respond_to?(:clear_cookies)
        rescue => e
          MagicTest.logger.warn("magic_test wizard: clear_cookies failed: #{e.message}")
        end
      end

      private

      def block
        codegen.block
      end

      # Lets and before-lines the target block already has: `let!` eagerly,
      # lazy `let` on first use, sign-ins translated to magic_sign_in.
      def evaluate_existing_lets(failures)
        return true unless block
        block.visible_lets.each { |let| define_lazy(let.name, let.body) }
        block.visible_lets.select(&:bang).all? { |let| fetch_let(let.name, "existing let!(:#{let.name})", failures) }
      end

      def evaluate_plan_lets(failures)
        codegen.let_entries.all? do |name, expr|
          define_lazy(name, expr)
          fetch_let(name, "let!(:#{name}) { #{expr} }", failures)
        end
      end

      def define_lazy(name, body)
        memo = records
        ctx = context
        context.define_singleton_method(name) do
          memo.key?(name) ? memo[name] : (memo[name] = ctx.instance_eval(body, "let(:#{name})", 1))
        end
        @defined << name.to_sym
      end

      def fetch_let(name, label, failures)
        context.public_send(name)
        true
      rescue Exception => e # rubocop:disable Lint/RescueException -- report every setup error to the human
        raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
        failures << classify(e, "lets", "models.#{name}", label)
        false
      end

      def check_records(failures)
        records.each do |name, value|
          Array(value).each do |record|
            next unless record.respond_to?(:persisted?)
            unless record.persisted?
              failures << Failure.new("records", "let!(:#{name}) built a #{record.class} that was not saved.", "use create (not build) or fix the validation errors: #{errors_of(record)}", "models.#{name}")
              next
            end
            if record.respond_to?(:valid?) && !record.valid?
              failures << Failure.new("records", "let!(:#{name}) is persisted but invalid: #{errors_of(record)}.", "set the attribute in the overrides or use another trait", "models.#{name}")
            end
          end
        end
      end

      def errors_of(record)
        record.respond_to?(:errors) ? record.errors.full_messages.join(", ") : "?"
      end

      def resolve_user(failures)
        return nil if plan.guest?
        expr = codegen.user_expression
        user = context.instance_eval(expr, "sign-in", 1)
        if user.nil?
          failures << Failure.new("sign_in", "#{expr} is nil: #{role_name} has no user to sign in with.", with_user_fix, "signed_in")
          return nil
        end
        user
      rescue Exception => e # rubocop:disable Lint/RescueException
        raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
        failures << if e.is_a?(NoMethodError) && e.message.include?("for nil")
          Failure.new("sign_in", "#{expr} raised #{e.message.lines.first.strip}: #{role_name} has no user to sign in with.", with_user_fix, "signed_in")
        else
          classify(e, "sign_in", "signed_in", expr)
        end
        nil
      end

      def with_user_fix
        role = role_name.to_s
        let = codegen.name_for(plan.signed_in)
        role.end_with?("Institution") ? "add trait :with_user to let!(:#{let}) (the institution needs a leader employee with a user)" : "add trait :with_user to let!(:#{let}) (or check the factory creates the user)"
      end

      def run_setup(failures, user)
        ok = codegen.setup_lines.reject { |l| l.start_with?("magic_sign_in(") }.all? { |line| evaluate(line, "before", "extras", failures) }
        ok &&= existing_sign_in_lines.all? { |line| evaluate(line, "before (existing)", "target.block", failures) }
        context.magic_sign_in(user) if ok && user
        ok
      end

      def evaluate(code, stage, field, failures)
        context.instance_eval(code, stage, 1)
        true
      rescue Exception => e # rubocop:disable Lint/RescueException -- every setup error is reported to the human
        raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
        failures << classify(e, stage, field, code)
        false
      end

      # Existing `before` lines of the target block chain other than the
      # driver line; `sign_in_as_x(let)` becomes magic_sign_in of that let's
      # user so Studiz's helper module need not be loaded here.
      def existing_sign_in_lines
        return [] unless block
        chain = []
        b = block
        while b
          chain.unshift(b)
          b = b.parent
        end
        chain.flat_map(&:before_lines).filter_map do |line|
          next if line.start_with?("driven_by")
          if (m = line.match(/\Asign_in_as_(\w+)\(([a-z_][a-z0-9_]*)\)\z/))
            let = plan.models.find { |mo| codegen.name_for(mo.let) == m[2] }
            klass = let ? catalogue.factory(let.factory)&.class_name : m[1].camelize
            "magic_sign_in(#{MagicTest.config.user_expression(klass, m[2])})"
          elsif line.match?(/\Asign_in_as_\w+\z/)
            nil # creates its own record; not our user
          else
            line
          end
        end
      end

      def visit(failures, notes, new_window:)
        expr = codegen.start_expression
        expected = context.instance_eval(expr, "visit", 1).to_s
        if new_window
          @recording_window = context.page.open_new_window
          context.page.switch_to_window(@recording_window)
        end
        context.visit(expected)
        page = context.page
        status = begin
          page.status_code
        rescue NotImplementedError, NoMethodError
          nil
        end
        path = page.current_path.to_s
        js_errors = []
        begin
          page.evaluate_script("1")
        rescue => e
          js_errors << e.message.lines.first.to_s.strip
        end
        title = begin
          page.title
        rescue
          ""
        end
        info = {status: status, url: page.current_url, path: path, expected_path: expected, title: title, js_errors: js_errors, screenshot: screenshot(page)}
        if login_path?(path)
          failures << Failure.new("visit", "#{expected} redirected to the login page (#{path}).", plan.guest? ? "the page needs a signed-in user: pick a role" : "the signed-in user was not accepted: does #{codegen.user_expression} resolve to a user that may see this page?", "start.route")
        elsif status == 403
          failures << Failure.new("visit", "#{expected} answered 403 Forbidden.", param_hint || "the signed-in #{role_name} does not own that record or may not see this page: check the route params point at the signed-in role's records", "start.route")
        elsif status == 404 || status == 500
          failures << Failure.new("visit", "#{expected} answered #{status}#{(status == 404) ? " Not Found" : " (an exception in the app; see log/test.log)"}.", param_hint || "a route param points at the wrong let (or the record is not visible to this role)", "start.params")
        elsif status && status >= 400
          failures << Failure.new("visit", "#{expected} answered #{status}.", "check the server log (log/test.log)", "start.route")
        elsif js_errors.any?
          failures << Failure.new("visit", "JavaScript error on #{path}: #{js_errors.first}", "fix the page's JavaScript; recording runs with js_errors: true and would stop here", "start.route")
        elsif path != expected.sub(/\?.*\z/, "")
          notes << "#{expected} redirected to #{path}"
        end
        info
      rescue Exception => e # rubocop:disable Lint/RescueException
        raise e if e.is_a?(SystemExit) || e.is_a?(Interrupt)
        failures << classify(e, "visit", "start.route", expr)
        {}
      end

      # ":institution_id is provider, a Provider" when a param's name and the let's class disagree.
      def param_hint
        route = catalogue.route(plan.start.route) or return nil
        route.params.filter_map do |part|
          let = plan.start.params[part]
          model = let && plan.model(let)
          next unless model
          klass = catalogue.factory(model.factory)&.class_name
          expected = part.sub(/_id\z/, "")
          next if part == "id" || klass.nil? || klass.demodulize.underscore == expected
          "the route param :#{part} points at #{let} (a #{klass}); it probably needs a let of class #{expected.camelize}"
        end.first
      end

      def screenshot(page)
        return nil unless page.driver.respond_to?(:render_base64)
        page.driver.render_base64(:png)
      rescue => e
        MagicTest.logger.warn("magic_test wizard: screenshot failed: #{e.message}")
        nil
      end

      def login_path?(path)
        paths = MagicTest.config.login_paths.dup
        begin
          paths << Rails.application.routes.url_helpers.new_user_session_path if Rails.application.routes.url_helpers.respond_to?(:new_user_session_path)
        rescue
          nil
        end
        paths.any? { |p| path == p || path.start_with?("#{p}/") || path.end_with?(p) }
      end

      def role_name
        model = plan.signed_in_model
        model ? catalogue.factory(model.factory)&.class_name : "guest"
      end

      def describe_user(user)
        email = user.respond_to?(:email) ? user.email : user.to_s
        "#{codegen.user_expression} (#{user.class}##{user.try(:id)} #{email})"
      end

      def record_summary
        records.flat_map do |name, value|
          Array(value).select { |r| r.respond_to?(:id) }.map { |r| {let: name.to_s, class: r.class.name, id: r.id} }
        end
      end

      # Makes the preflight values the example's `let` values, so the
      # recorder maps ids to let names exactly as it would in the spec.
      def install_memoized!
        return unless context.respond_to?(:__memoized, true)
        memo = context.send(:__memoized).instance_variable_get(:@memoized)
        records.each { |name, value| memo[name.to_sym] = value } if memo.is_a?(Hash)
      end

      # Turns an exception into a failure with a concrete fix.
      def classify(error, stage, field, label)
        message = error.message.to_s.lines.first.to_s.strip
        fix = case error
        when KeyError
          if message.match?(/Trait not registered/) then "check the trait name; known traits are listed in the picker"
          elsif message.match?(/Factory not registered/) then "check the factory name"
          else "check the factory definition"
          end
        else
          if defined?(ActiveRecord::NotNullViolation) && error.is_a?(ActiveRecord::NotNullViolation)
            column = message[/NOT NULL constraint failed: \w+\.(\w+)/, 1] || message[/column "(\w+)"/, 1]
            column ? "#{column} is NOT NULL: wire the #{column.sub(/_id\z/, "")} association to a let or set the attribute" : "a NOT NULL column is empty: wire the association or set the attribute"
          elsif defined?(ActiveRecord::RecordInvalid) && error.is_a?(ActiveRecord::RecordInvalid)
            "set the attribute in the overrides or pick a trait that fills it"
          elsif error.is_a?(NoMethodError) && message.include?("for nil")
            "something in the chain is nil (a parent without a user or an association that was not wired)"
          elsif error.is_a?(NameError) && message.match?(/undefined local variable or method/)
            "the let it refers to does not exist in this plan"
          elsif defined?(ActionController::UrlGenerationError) && error.is_a?(ActionController::UrlGenerationError)
            "a route param is missing or points at the wrong let"
          elsif error.is_a?(ArgumentError) && message.match?(/wrong number of arguments/)
            "the route helper got the wrong number of params"
          else
            "edit the plan and run preflight again"
          end
        end
        Failure.new(stage, "#{label}: #{error.class}: #{message}", fix, field)
      end
    end
  end
end
