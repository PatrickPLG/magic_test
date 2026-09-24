require "securerandom"
require "json"
require "fileutils"
require "monitor"
require "magic_test/capybara_xpath"
require "magic_test/i18n_index"
require "magic_test/route_resolver"
require "magic_test/codegen"
require "magic_test/spec_writer"
require "magic_test/call_site"
require "magic_test/console"
require "magic_test/scripted_session"

module MagicTest
  # One recording session: the server-side source of truth for events,
  # requests, generated steps and toolbar commands. `Session.run` blocks the
  # spec's main thread on the command queue until the toolbar (or a scripted
  # human) finishes the session.
  class Session
    MAIN_THREAD_COMMANDS = %w[save save_and_finish finish replay_pending open_console abort].freeze

    Command = Struct.new(:name, :params, :result_queue)

    attr_reader :id, :call_site, :page, :event_log, :request_log, :status, :example, :messages, :writer, :context

    def self.run(page:, call_site:, example: nil, context: nil)
      session = new(page: page, call_site: call_site, example: example, context: context)
      MagicTest.current_session = session
      session.start
      session.run_loop
      session.raise_abort!
      session
    ensure
      MagicTest.current_session = nil
    end

    def initialize(page:, call_site:, example: nil, context: nil)
      @id = SecureRandom.hex(6)
      @page = page
      @call_site = call_site
      @example = example
      @context = context
      @event_log = EventLog.new
      @request_log = RequestLog.new
      adopt_recent_requests
      @queue = Queue.new
      @mutex = Monitor.new # reentrant: inline commands rebuild steps while holding it
      @status = :recording
      @messages = []
      @overrides = {}
      @deleted_event_ids = []
      @accepted_suggestions = []
      @saved_step_count = 0
      @frozen_event_ids = []
      @i18n_keys = MagicTest.config.i18n_keys
      @i18n_indexes = {}
      @writer = SpecWriter.new(path: call_site.path, line: call_site.line, source_line: call_site.source_line)
      @started_at = Time.now
      @dialog_answer = nil
      @pending_dialog = nil
      @mode = "record"
      @replay_results = {}
      @steps_cache = nil
      @steps_version = nil
      @version = 0
    end

    def config
      MagicTest.config
    end

    def start
      @started_at ||= Time.now
      puts "\nmagic_test #{MagicTest::VERSION}: recording #{call_site.path}:#{call_site.line}"
      puts "  Use the toolbar in the browser: Save writes the steps above the `magic_test` line; Save & finish returns to the spec."
      puts "  Scripted session: #{ENV["MAGIC_TEST_SCRIPT"]}" if ENV["MAGIC_TEST_SCRIPT"].present?
      @scripted = ScriptedSession.start(self) if ENV["MAGIC_TEST_SCRIPT"].present?
    end

    def run_loop
      loop do
        command = @queue.pop
        result = process_main_thread_command(command)
        command.result_queue << result
        break if @status == :finished
      end
    ensure
      @scripted&.join(5)
    end

    def finished?
      @status == :finished
    end

    # A scripted human that failed aborts the session; the example must fail.
    def raise_abort!
      raise MagicTest::Error, "scripted session aborted: #{@abort_error}" if @abort_error.present?
    end

    def i18n_keys?
      @i18n_keys
    end

    def known_ids
      ids = request_log.record_ids
      ids += memoized.values.select { |v| v.respond_to?(:id) && defined?(ActiveRecord::Base) && v.is_a?(ActiveRecord::Base) }.map { |v| v.id.to_s }
      ids.uniq
    end

    # The example's memoised `let` values (name => value), when RSpec is in use.
    def memoized
      return {} unless context.respond_to?(:__memoized, true)
      memo = context.send(:__memoized)
      hash = memo.instance_variable_get(:@memoized) || {}
      hash.to_h
    rescue
      {}
    end

    # Reverse index for the given locale (default: the locale of the last
    # request, so an `/en/...` page resolves against the English catalogue).
    def i18n_index(locale = nil)
      locale = (locale.presence || request_log.last&.locale.presence || config.locale || I18n.locale).to_sym
      @i18n_indexes[locale] ||= I18nIndex.new(locale)
    end

    def route_resolver
      @route_resolver ||= RouteResolver.new
    end

    def fixture_file_exists?(relative)
      File.exist?(File.join(Rails.root.to_s, relative))
    end

    # ---- browser-facing API ---------------------------------------------------

    def receive_events(events)
      acked = []
      events.each do |event|
        next unless event.is_a?(Hash) && event["id"]
        if event["kind"] == "candidates_update"
          event_log.update(event["event_id"]) do |e|
            e["candidates"] = event["candidates"]
            e["modal"] = event["modal"] if event["modal"]
          end
          acked << event["id"]
          bump
          next
        end
        note_dialog(event)
        added = event_log.add(event)
        acked << event["id"]
        bump if added
      end
      acked
    end

    def config_payload
      {
        "status" => status.to_s, "session_id" => id, "version" => @version,
        "started_at" => (@started_at || Time.now).to_f * 1000,
        "xpath" => CapybaraXPath.templates, "capybara" => CapybaraXPath.session_settings,
        "known_ids" => known_ids, "modals" => config.studiz_modals,
        "ignored_paths" => config.ignored_request_paths.map(&:source),
        "poll_interval_ms" => config.poll_interval_ms, "max_ancestor_depth" => config.max_ancestor_depth,
        "call_site" => call_site.to_h, "i18n_keys" => @i18n_keys, "mode" => @mode,
        # A scripted human never looks at the panel, and it would cover page
        # elements a person would simply drag it away from.
        "toolbar" => ENV["MAGIC_TEST_SCRIPT"].blank? || ENV["MAGIC_TEST_TOOLBAR"].present?
      }
    end

    def state_payload
      steps, suggestions = build
      {
        "status" => status.to_s, "session_id" => id, "version" => @version,
        "steps" => steps.map(&:to_h), "saved_count" => @saved_step_count,
        "pending_code" => Codegen::Emitter.new(steps[@saved_step_count..] || []).render,
        "suggestions" => suggestions.map { |s| s.to_h.merge("label" => s.meta[:label]) },
        "setup" => setup_suggestions, "messages" => @messages.last(5),
        "i18n_keys" => @i18n_keys, "known_ids" => known_ids, "mode" => @mode, "mode_options" => @mode_options || {},
        "dialog_answer" => @dialog_answer, "pending_dialog" => @pending_dialog,
        "replay" => @replay_results, "call_site" => call_site.to_h,
        "console" => Console.available?
      }
    end

    # Commands from the toolbar (or a scripted human). Main-thread commands
    # are queued and awaited; the rest are applied immediately.
    def enqueue_command(name, params = {})
      if MAIN_THREAD_COMMANDS.include?(name)
        command = Command.new(name: name, params: params, result_queue: Queue.new)
        @queue << command
        result = command.result_queue.pop(timeout: config.command_timeout)
        result || {ok: false, error: "command #{name} timed out after #{config.command_timeout}s"}
      else
        @mutex.synchronize { process_inline_command(name, params) }
      end
    end

    # ---- steps ----------------------------------------------------------------

    def build
      @mutex.synchronize do
        return [@steps_cache, @suggestions_cache] if @steps_cache && @steps_version == @version
        events = event_log.all.reject { |e| @deleted_event_ids.include?(e["id"]) }
        builder = Codegen::Builder.new(events, session: self, overrides: @overrides)
        steps, suggestions = builder.build
        steps += @accepted_suggestions
        steps.each { |s| s.confidence = :red if s.review.present? && s.confidence == :green }
        @steps_cache = steps
        @suggestions_cache = suggestions.reject { |s| @accepted_suggestions.any? { |a| a.lines == s.lines } }
        @steps_version = @version
        [@steps_cache, @suggestions_cache]
      end
    end

    def steps
      build.first
    end

    def pending_steps
      steps[@saved_step_count..] || []
    end

    def pending_lines
      Codegen::Emitter.new(pending_steps).render
    end

    # Writes pending steps above the magic_test call.
    def save!
      lines = pending_lines
      return {ok: true, message: "nothing to save", lines: 0} if lines.empty?
      new_line = writer.insert_above(lines)
      @saved_step_count = steps.size
      @frozen_event_ids = steps.flat_map(&:event_ids)
      @accepted_suggestions.each { |s| @saved_step_count } # accepted suggestions are part of steps
      @call_site.line = new_line
      message = "wrote #{lines.size} line(s) to #{call_site.path}:#{new_line}"
      @messages << message
      puts "magic_test: #{message}"
      {ok: true, message: message, lines: lines.size}
    rescue SpecWriter::Error => e
      @messages << e.message
      {ok: false, error: e.message, message: e.message}
    end

    def write_raw_lines!(lines)
      new_line = writer.insert_above(lines)
      @call_site.line = new_line
      bump
      true
    end

    attr_reader :frozen_event_ids

    private

    PRE_SESSION_WINDOW = 60 # seconds

    # MAGIC_TEST_DEBUG_DIR=tmp/magic_test writes the raw event log, request
    # log and generated steps as JSON when the session ends (troubleshooting).
    def dump_debug!
      dir = ENV["MAGIC_TEST_DEBUG_DIR"].presence or return
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "#{File.basename(call_site.path, ".rb")}-#{id}.json")
      payload = {
        call_site: {path: call_site.path, line: call_site.line},
        events: event_log.all,
        requests: request_log.all.map(&:to_h),
        steps: steps.map { |s| {kind: s.kind, lines: s.lines, scopes: s.scopes.map(&:to_h), confidence: s.confidence, review: s.review} }
      }
      File.write(path, JSON.pretty_generate(payload))
      puts "magic_test: debug dump written to #{path}"
    rescue => e
      MagicTest.logger.warn("magic_test: debug dump failed: #{e.class}: #{e.message}")
    end

    # The page the spec loaded before `magic_test` (and its record ids).
    def adopt_recent_requests
      recent = MagicTest.pre_session_request_log.all.select { |r| Time.now.to_f - r.at.to_f < PRE_SESSION_WINDOW }
      recent.each { |r| @request_log.add(r) }
      MagicTest.pre_session_request_log.clear
    end

    def bump
      @mutex.synchronize { @version += 1 }
    end

    def note_dialog(event)
      case event["kind"]
      when "dialog_opened" then @pending_dialog = event.slice("id", "message", "dialog_type")
      when "dialog"
        @pending_dialog = nil
        @dialog_answer = nil
      end
    end

    def process_main_thread_command(command)
      case command.name
      when "save" then save!
      when "save_and_finish"
        result = save!
        finish! if result[:ok]
        result
      when "finish"
        finish!
        {ok: true, message: "finished"}
      when "abort"
        @abort_error = command.params["error"].to_s
        finish!
        {ok: true}
      when "replay_pending" then replay_pending
      when "open_console"
        opened = Console.open(binding)
        opened ? {ok: true, message: "console closed"} : {ok: false, error: "Pry is not available in this process"}
      else
        {ok: false, error: "unknown command #{command.name}"}
      end
    rescue => e
      {ok: false, error: "#{e.class}: #{e.message}"}
    end

    def finish!
      @status = :finished
      dump_debug!
      bump
      puts "magic_test: session finished (#{steps.size} step(s), #{@saved_step_count} saved)."
    end

    def process_inline_command(name, params)
      case name
      when "ping" then {ok: true}
      when "pause"
        @status = :paused
        {ok: true}
      when "resume"
        @status = :recording
        {ok: true}
      when "discard"
        pending_ids = pending_steps.flat_map(&:event_ids)
        @deleted_event_ids.concat(pending_ids)
        @accepted_suggestions.clear
        @version += 1
        {ok: true, message: "discarded #{pending_ids.size} event(s)"}
      when "delete_step"
        step = steps.find { |s| s.id == params["step_id"] }
        return {ok: false, error: "unknown step"} unless step
        return {ok: false, error: "step already saved"} if steps.index(step) < @saved_step_count
        if step.suggestion || @accepted_suggestions.include?(step)
          @accepted_suggestions.delete(step)
        else
          @deleted_event_ids.concat(step.event_ids)
        end
        @version += 1
        {ok: true}
      when "set_locator"
        step = steps.find { |s| s.id == params["step_id"] }
        return {ok: false, error: "unknown step"} unless step
        step.event_ids.each do |eid|
          @overrides[eid] = (@overrides[eid] || {}).merge(params.slice("locator", "code", "i18n"))
        end
        @version += 1
        {ok: true}
      when "toggle_i18n"
        @i18n_keys = params.key?("value") ? !!params["value"] : !@i18n_keys
        @version += 1
        {ok: true, i18n_keys: @i18n_keys}
      when "accept_suggestion"
        _, suggestions = build
        s = suggestions.find { |x| x.id == params["suggestion_id"] } || suggestions.find { |x| x.lines == [params["code"]] }
        return {ok: false, error: "unknown suggestion"} unless s
        chosen = params["alternative"].present? ? Codegen::Step.new(kind: s.kind, lines: [params["alternative"]], event_ids: s.event_ids) : Codegen::Step.new(kind: s.kind, lines: s.lines, event_ids: s.event_ids)
        chosen.lines = chosen.lines.map { |l| l.sub("STEPS", "# steps") }
        @accepted_suggestions << chosen
        @version += 1
        {ok: true}
      when "answer_dialog"
        @dialog_answer = {"answer" => params["answer"].to_s, "response" => params["response"], "at" => Time.now.to_f}
        {ok: true}
      when "set_mode"
        @mode = params["mode"].to_s.presence || "record"
        @mode_options = params.slice("assertion_type", "text")
        @version += 1
        {ok: true, mode: @mode}
      when "message"
        @messages << params["text"].to_s
        {ok: true}
      else
        {ok: false, error: "unknown command #{name}"}
      end
    end

    # Proves that every pending step's locator resolves in the live page,
    # without performing the actions.
    def replay_pending
      results = {}
      pending_steps.each do |step|
        results[step.id] = verify_step(step)
      end
      @replay_results = results
      bump
      {ok: results.values.all? { |r| r["ok"] != false }, replay: results}
    end

    def verify_step(step)
      kind = step.meta[:selector_kind] || step.kind.to_s
      literal = step.locator
      return {"ok" => nil, "note" => "not verifiable"} if literal.nil? || %i[visit assert dialog error].include?(step.kind)
      node = page.document
      step.scopes.each do |scope|
        next unless scope.kind == :within
        css, text = scope.key.split(":", 3).drop(1)
        node = text.present? ? node.find(css, text: text, wait: 2) : node.find(css, wait: 2)
      end
      count = case step.kind
      when :click then CapybaraXPath.smart_count(node, :link_or_button, literal)
      when :fill, :enter, :flatpickr then CapybaraXPath.smart_count(node, :fillable_field, literal)
      when :check then CapybaraXPath.smart_count(node, :checkbox, literal, visible: :all)
      when :choose then CapybaraXPath.smart_count(node, :radio_button, literal, visible: :all)
      when :select, :chosen then CapybaraXPath.smart_count(node, :select, literal, visible: :all)
      when :attach_file, :attach_image then CapybaraXPath.smart_count(node, :file_field, literal, visible: :all)
      when :trix then node.all("trix-editor##{literal}, trix-editor[input=#{literal.inspect}]", wait: 0).size
      else node.all(literal, wait: 0).size
      end
      {"ok" => count == 1, "found" => count, "kind" => kind}
    rescue => e
      {"ok" => false, "error" => "#{e.class}: #{e.message.lines.first&.strip}"}
    end

    def setup_suggestions
      out = []
      source = File.exist?(call_site.path) ? File.read(call_site.path) : ""
      user = request_log.all.map(&:user).compact.last
      if user && !source.match?(/sign_in|login_as/)
        role = user["role_type"].to_s.demodulize.underscore
        role_class = user["role_type"].to_s.safe_constantize
        let_name = memoized.find { |_n, v| role_class && v.instance_of?(role_class) && v.id == user["role_id"] }&.first || role
        out << {"kind" => "sign_in", "code" => "sign_in_as_#{role}(#{let_name})", "alt" => "magic_sign_in(#{let_name}.user)", "note" => "the spec has no sign-in call yet"}
      end
      out.concat(factory_suggestions)
      out
    rescue => e
      [{"kind" => "error", "note" => e.message}]
    end

    def factory_suggestions
      return [] unless defined?(FactoryBot)
      lets = memoized
      known = lets.values.select { |v| v.respond_to?(:id) && v.is_a?(ActiveRecord::Base) }
      seen = {}
      request_log.html_page_loads.each do |r|
        result = route_resolver.resolve(r.path, memoized: lets)
        result.args.each do |arg|
          next unless arg.review? && arg.code.include?(".find(")
          model = arg.code.split(".find(").first
          next if seen[model]
          seen[model] = true
          factory = model.underscore.tr("/", "_").to_sym
          next unless FactoryBot.factories.registered?(factory) || FactoryBot.factories.registered?(model.demodulize.underscore.to_sym)
          factory = FactoryBot.factories.registered?(factory) ? factory : model.demodulize.underscore.to_sym
          klass = model.safe_constantize
          assoc = klass ? klass.reflect_on_all_associations(:belongs_to).filter_map do |a|
            owner = begin
              known.find { |k| k.is_a?(a.klass) }
            rescue
              nil
            end
            owner && "#{a.name}: #{lets.key(owner)}"
          end : []
          code = "let!(:#{factory}) { create(:#{factory}#{", #{assoc.join(", ")}" if assoc.any?}) }"
          yield_code = "# TODO(magic_test): add to the example's setup and re-run:\n#{code}"
          @setup_codes ||= {}
          @setup_codes[model] = yield_code
        end
      end
      (@setup_codes || {}).map { |model, code| {"kind" => "factory", "model" => model, "code" => code, "note" => "record #{model} came from the page, not from a let"} }
    end
  end
end
