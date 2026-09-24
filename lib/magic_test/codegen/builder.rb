module MagicTest
  module Codegen
    # Turns the ordered intent events posted by the browser into Steps.
    # All Ruby literal generation happens here (the browser sends raw data).
    class Builder
      CLICK_KINDS = %w[link_or_button].freeze
      LINK_KINDS = %w[link].freeze
      BUTTON_KINDS = %w[button].freeze
      FIELD_KINDS = %w[fillable_field field].freeze

      Context = Struct.new(:window, :frame, :modal, :window_vars, :seen_navigation)

      attr_reader :steps, :suggestions

      # @param events [Array<Hash>] ordered intent events
      # @param session [Session] gives access to config, i18n index, route resolver, request log, memoized lets
      def initialize(events, session:, overrides: {})
        @events = events
        @session = session
        @overrides = overrides # step id → {locator:, i18n:}
        @steps = []
        @suggestions = []
        @ctx = Context.new(window: "main", frame: nil, modal: nil, window_vars: {}, seen_navigation: false)
        @pending_file = nil
        @window_step = nil
      end

      def build
        @events.each do |event|
          handle(event)
        rescue => e
          MagicTest.logger.error("magic_test: could not convert event #{event["id"]} (#{event["kind"]}): #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
          add(Step.new(kind: :error, lines: [], review: "event #{event["kind"]} could not be converted: #{e.message}", confidence: :red, event_ids: [event["id"]]))
        end
        finish_pending_file
        [@steps, @suggestions]
      end

      private

      def handle(event)
        db_suggestions(event) unless %w[navigation].include?(event["kind"])
        case event["kind"]
        when "navigation" then navigation(event)
        when "modal" then modal(event)
        when "click" then click(event)
        when "fill" then fill(event)
        when "enter" then enter(event)
        when "check" then check(event)
        when "choose" then choose(event)
        when "select" then select(event)
        when "chosen" then chosen(event)
        when "flatpickr" then flatpickr(event)
        when "trix" then trix(event)
        when "file" then file(event)
        when "crop_apply" then crop_apply(event)
        when "dialog" then dialog(event)
        when "hover" then hover(event)
        when "assert" then assertion(event)
        when "toast" then toast(event)
        when "window" then window_event(event)
        end
      end

      # ---- helpers -----------------------------------------------------------

      # The HTML page the event happened on: the last page load whose request
      # started before the event (a navigation the event itself triggered
      # starts after it). Browser and server share a clock in system tests.
      def request_for(event)
        ts = event["ts"].to_f / 1000.0
        loads = @session.request_log.html_page_loads
        loads.reverse.find { |r| r.started_at.to_f <= ts } || loads.first
      end

      # The I18n index and locale of the page the event happened on.
      def i18n_for(event)
        locale = (request_for(event)&.locale.presence || @session.request_log.last&.locale.presence || I18n.locale).to_sym
        [@session.i18n_index(locale), locale]
      end

      # `I18n.t('key')`, plus `locale: :en` when the page was not rendered in
      # the default locale (the replaying spec runs in the default locale).
      def t_code(match, locale)
        Codegen.t_code(match.key, match.respond_to?(:interpolations) ? match.interpolations : {}, locale)
      end

      # Text as an I18n lookup when a unique key renders it, else a literal.
      def text_code(text, event, scopes: [])
        index, locale = i18n_for(event)
        key, = index.best(text.to_s, scopes: scopes)
        (key && @session.i18n_keys?) ? t_code(key, locale) : RubyLiteral.string(text.to_s)
      end

      def picker(event)
        request = request_for(event) || @session.request_log.last
        # Partials rendered by the last XHR before the event (an ajax modal's form) count too.
        ts = event["ts"].to_f / 1000.0
        templates_request = @session.request_log.all.reverse.find { |r| r.templates.present? && r.started_at.to_f <= ts }
        scopes = ((request&.template_scopes || []) + (templates_request&.template_scopes || [])).uniq
        index, locale = i18n_for(event)
        LocatorPicker.new(known_ids: @session.known_ids, i18n_index: index, i18n_locale: locale,
          i18n_keys: @session.i18n_keys?, template_scopes: scopes,
          namespace: scopes.first&.split(".")&.first)
      end

      def override_for(event_ids)
        @overrides.values_at(*event_ids).compact.first || {}
      end

      def pick(event, kinds:, allow_css: true)
        ov = override_for([event["id"]])
        i18n = ov.key?("i18n") ? ov["i18n"] : true
        candidates = event["candidates"] || []
        if ov["locator"]
          chosen = candidates.find { |c| c["locator"] == ov["locator"] }
          candidates = [chosen] + (candidates - [chosen]) if chosen
        end
        picker(event).pick(candidates, kinds: kinds, i18n: i18n, allow_css: allow_css).tap do |choice|
          choice.code = ov["code"] if ov["code"]
        end
      end

      def scopes_for(event, choice = nil)
        chain = []
        win = event["window"] && event["window"]["id"]
        if win && win != "main"
          var = @ctx.window_vars[win] ||= (@ctx.window_vars.empty? ? "new_window" : "new_window_#{@ctx.window_vars.size + 1}")
          chain << Scope.new(kind: :window, open: "within_window(#{var}) do", key: "window:#{win}")
        end
        if (frame = event["frame"]).present?
          frame_key = frame["locator"] || frame["css"]
          generation = @frame_generation && @frame_generation[frame_key] || 0
          chain << Scope.new(kind: :frame, open: "within_frame(#{frame_locator(frame)}) do", key: "frame:#{frame_key}##{generation}")
        end
        modal = event.key?("modal") ? event["modal"].presence : @ctx.modal
        if modal && event["in_modal"] != false
          chain << Scope.new(kind: :within, open: "within(#{RubyLiteral.string(modal)}) do", key: "within:#{modal}")
        end
        if choice&.scope && choice.scope["css"] != modal
          s = choice.scope
          if s["kind"] == "nth" && s["index"]
            index = s["index"].to_i
            chain << Scope.new(kind: :within, open: "within(all(#{RubyLiteral.string(s["css"])}, minimum: #{index + 1})[#{index}]) do", key: "within:#{s["css"]}[#{index}]")
          else
            args = [RubyLiteral.string(s["css"])]
            args << "text: #{RubyLiteral.string(s["text"])}" if s["text"].present?
            chain << Scope.new(kind: :within, open: "within(#{args.join(", ")}) do", key: "within:#{s["css"]}:#{s["text"]}")
          end
        end
        chain
      end

      def frame_locator(frame)
        if frame["locator"].present?
          RubyLiteral.string(frame["locator"])
        else
          "find(#{RubyLiteral.string(frame["css"])})"
        end
      end

      def add(step)
        @steps << step
        step
      end

      def add_step(event, kind, lines, choice, extra_review: nil, meta: {})
        review = [choice&.review, extra_review].compact.join("; ").presence
        add(Step.new(kind: kind, lines: Array(lines), scopes: scopes_for(event, choice), confidence: choice&.confidence || :green,
          review: review, candidates: choice&.alternatives || [], event_ids: [event["id"]], locator: choice&.literal,
          i18n: !!choice&.i18n_key, meta: meta))
      end

      def previous_step
        @steps.last
      end

      # `dialog` is the dialog event (dialog_type, message, answer, response).
      def wrap_last_for_dialog(step, dialog)
        method = case dialog["dialog_type"]
        when "confirm" then (dialog["answer"] == "dismiss") ? "dismiss_confirm" : "accept_confirm"
        when "prompt" then (dialog["answer"] == "dismiss") ? "dismiss_prompt" : "accept_prompt"
        else "accept_alert"
        end
        args = []
        args << text_code(dialog["message"], dialog) if dialog["message"].present?
        args << "with: #{RubyLiteral.string(dialog["response"])}" if method == "accept_prompt" && dialog["response"].present?
        step.wrapper = Wrapper.new(open: "#{method}#{"(#{args.join(", ")})" if args.any?} do")
        step.meta[:dialog] = dialog
      end

      # ---- event handlers ----------------------------------------------------

      def navigation(event)
        if (frame = event["frame"]).present? && event["how"].to_s != "initial"
          # Cuprite loses the frame's execution context when the frame navigates;
          # later steps re-enter the frame in a new within_frame block.
          @frame_generation ||= Hash.new(0)
          @frame_generation[frame["locator"] || frame["css"]] += 1
          return
        end
        first = !@ctx.seen_navigation
        @ctx.seen_navigation = true
        initial = event["how"].to_s == "initial"
        typed = !initial && (event["how"].to_s == "typed" || first)
        path = event["path"].presence || event["url"]
        result = @session.route_resolver.resolve(path, method: :get, memoized: @session.memoized)
        helper = result.code
        if typed
          lines = helper ? "visit(#{helper})" : "visit(#{RubyLiteral.string(path)})"
          review = result.review? ? [result.review, *result.args.map(&:review)].compact.join("; ") : nil
          review ||= "no route helper found for #{path}" unless helper
          add(Step.new(kind: :visit, lines: [lines], scopes: scopes_for(event), confidence: review ? :red : :green, review: review, event_ids: [event["id"]]))
        elsif helper && !initial
          ignore_query = path.to_s.include?("?")
          helper = @session.route_resolver.resolve(path.to_s.sub(/\?.*\z/, ""), method: :get, memoized: @session.memoized).code || helper if ignore_query
          suggest(:current_path, Assertions.current_path(helper, ignore_query: ignore_query), "Assert current path", event)
        end
        flash_suggestions(event)
      end

      def flash_suggestions(event)
        record = request_for(event)
        return unless record && record.flash.present?
        record.flash.each_value do |msg|
          next if msg.blank?
          suggest(:flash, Assertions.content(text_code(msg, event, scopes: record.template_scopes)), "Assert flash #{msg.to_s.truncate(40)}", event)
        end
        db_suggestions(event)
      end

      def db_suggestions(event)
        record = @session.request_log.all.reverse.find { |r| !r.get? && r.db_changes.present? }
        return unless record && !@suggested_db_for&.include?(record.id)
        (@suggested_db_for ||= []) << record.id
        record.db_changes.each do |change|
          model = change[:model] || change["model"]
          op = (change[:operation] || change["operation"]).to_s
          next unless model
          begin
            case op
            when "insert"
              count = model.constantize.count
              house = Assertions.model_count(model, count)
              block = Assertions.count_change(model, change[:count] || change["count"] || 1)
              suggest(:db_count, house, "Assert #{model}.count == #{count}", event, alternatives: [block])
            when "update"
              reload_suggestions(record, model, event)
            when "delete"
              count = model.constantize.count
              suggest(:db_count, Assertions.model_count(model, count), "Assert #{model}.count == #{count}", event)
            end
          rescue => e
            MagicTest.logger.warn("magic_test: db suggestion for #{model} failed: #{e.message}")
          end
        end
      end

      def reload_suggestions(record, model, event)
        klass = model.constantize
        param_key = klass.model_name.param_key
        attrs = record.params && (record.params[param_key] || record.params[param_key.to_s])
        return unless attrs.is_a?(Hash)
        var, rec = @session.memoized.find { |_n, v| v.is_a?(klass) && (record.record_ids || []).include?(v.id.to_s) }
        if var.nil?
          # Singular resources (`/profil`) carry no id: the only let of that class is the record.
          same_class = @session.memoized.select { |_n, v| v.is_a?(klass) }
          var, rec = same_class.first if same_class.size == 1
        end
        return unless var
        rec.reload
        attrs.each do |attr, value|
          next unless rec.respond_to?(attr) && value.is_a?(String)
          current = rec.public_send(attr)
          matches = current.to_s == value.to_s ||
            (current.is_a?(Date) && value.scan(/\d+/).map(&:to_i).sort == [current.year, current.month, current.day].sort) ||
            (current.is_a?(Numeric) && value.match?(/\A-?\d+(\.\d+)?\z/) && current == (value.include?(".") ? value.to_f : value.to_i)) ||
            ([true, false].include?(current) && %w[1 0 true false].include?(value) && current == %w[1 true].include?(value))
          next unless matches
          suggest(:db_attr, Assertions.reload_attr(var, attr, RubyLiteral.value(current)), "Assert #{var}.#{attr}", event)
        end
      end

      def suggest(kind, code, label, event, alternatives: [])
        return if @suggestions.any? { |s| s.lines == [code] }
        @suggestions << Step.new(kind: kind, lines: [code], suggestion: true, event_ids: [event["id"]],
          candidates: alternatives.map { |a| {"code" => a, "label" => "block form"} }, meta: {label: label})
      end

      def modal(event)
        selector = event["selector"]
        if event["action"] == "shown"
          @ctx.modal = selector
        elsif @ctx.modal == selector
          @ctx.modal = nil
          suggest(:modal_closed, Assertions.no_css(RubyLiteral.string("#{selector}.show")), "Assert modal closed", event) if event["after_submit"]
        end
      end

      def window_event(event)
        # nothing to emit: the opening click carries `effects.window_opened`
      end

      def toast(event)
        text = event["text"].to_s
        return if text.blank?
        suggest(:toast, Assertions.content(text_code(text, event)), "Assert toast #{text.truncate(40)}", event)
      end

      def click(event)
        target = event["target"] || {}
        role = event["role"].to_s
        choice, method = click_choice(event, target, role)
        lines = if method == "find"
          "find(#{choice.code}).click"
        else
          "#{method}(#{choice.code})"
        end
        step = add_step(event, :click, lines, choice)
        if event.dig("effects", "window_opened")
          @ctx.window_vars["pending"] = true
          var = (@ctx.window_vars.empty? || @ctx.window_vars.keys == ["pending"]) ? "new_window" : "new_window_#{@ctx.window_vars.size}"
          step.wrapper = Wrapper.new(open: "#{var} = window_opened_by do")
          step.meta[:window_var] = var
          @window_step = step
        end
        step
      end

      # Semantic click (link_or_button) first; kind-specific when the text is
      # ambiguous across links and buttons; CSS otherwise.
      def click_choice(event, target, role)
        if %w[link button submit].include?(role)
          choice = pick(event, kinds: CLICK_KINDS, allow_css: false)
          return [choice, "click_on"] if choice.unique
          specific_kinds = (role == "link") ? LINK_KINDS : BUTTON_KINDS
          specific = pick(event, kinds: specific_kinds, allow_css: false)
          return [specific, (role == "link") ? "click_link" : "click_button"] if specific.unique
          css = pick(event, kinds: [], allow_css: true)
          return [css, "find"] if css.unique
          return [choice, "click_on"]
        end
        [pick(event, kinds: [], allow_css: true), "find"]
      end

      def fill(event)
        value = event["value"].to_s
        prev = previous_step
        if prev && prev.kind == :fill && prev.meta[:fingerprint] == event.dig("target", "fingerprint") && prev.scopes == scopes_for(event)
          prev.lines = ["fill_in(#{prev.meta[:locator_code]}, with: #{RubyLiteral.string(value)})"]
          prev.event_ids << event["id"]
          prev.meta[:value] = value
          return prev
        end
        choice = pick(event, kinds: FIELD_KINDS, allow_css: false)
        add_step(event, :fill, "fill_in(#{choice.code}, with: #{RubyLiteral.string(value)})", choice,
          meta: {fingerprint: event.dig("target", "fingerprint"), locator_code: choice.code, value: value})
      end

      def enter(event)
        return unless event["submitted"]
        choice = pick(event, kinds: FIELD_KINDS, allow_css: false)
        add_step(event, :enter, "find_field(#{choice.code}).send_keys(:enter)", choice)
      end

      def check(event)
        choice = pick(event, kinds: %w[checkbox], allow_css: false)
        method = event["checked"] ? "check" : "uncheck"
        args = [choice.code]
        args << "allow_label_click: true" if event["hidden"]
        add_step(event, :check, "#{method}(#{args.join(", ")})", choice)
      end

      def choose(event)
        choice = pick(event, kinds: %w[radio_button], allow_css: false)
        args = [choice.code]
        args << "allow_label_click: true" if event["hidden"]
        add_step(event, :choose, "choose(#{args.join(", ")})", choice)
      end

      def select(event)
        choice = pick(event, kinds: %w[select], allow_css: false)
        lines = []
        if event["multiple"]
          Array(event["added"]).each { |opt| lines << "select(#{RubyLiteral.string(opt)}, from: #{choice.code})" }
          Array(event["removed"]).each { |opt| lines << "unselect(#{RubyLiteral.string(opt)}, from: #{choice.code})" }
        end
        lines << "select(#{RubyLiteral.string(event["selected"]&.first)}, from: #{choice.code})" if lines.empty? && event["selected"].present?
        return if lines.empty?
        add_step(event, :select, lines, choice)
      end

      def chosen(event)
        choice = pick(event, kinds: %w[select], allow_css: false)
        method = (event["action"] == "unselect") ? "magic_chosen_unselect" : "magic_chosen_select"
        add_step(event, :chosen, "#{method}(#{RubyLiteral.string(event["option"])}, from: #{choice.code})", choice)
      end

      def flatpickr(event)
        choice = pick(event, kinds: FIELD_KINDS, allow_css: false)
        add_step(event, :flatpickr, "magic_set_date(#{choice.code}, #{RubyLiteral.string(event["value"])})", choice)
      end

      def trix(event)
        prev = previous_step
        text = event["value_text"].to_s
        if prev && prev.kind == :trix && prev.meta[:fingerprint] == event.dig("target", "fingerprint")
          prev.lines = ["magic_fill_trix(#{prev.meta[:locator_code]}, with: #{RubyLiteral.string(text)})"]
          prev.event_ids << event["id"]
          return prev
        end
        choice = pick(event, kinds: %w[trix], allow_css: false)
        add_step(event, :trix, "magic_fill_trix(#{choice.code}, with: #{RubyLiteral.string(text)})", choice,
          meta: {fingerprint: event.dig("target", "fingerprint"), locator_code: choice.code})
      end

      def file(event)
        finish_pending_file
        choice = pick(event, kinds: %w[file_field], allow_css: false)
        name = Array(event["files"]).first.to_s
        path_code, review = fixture_path(name)
        @pending_file = {event: event, choice: choice, path_code: path_code, review: review, hidden: event["hidden"]}
      end

      def crop_apply(event)
        if @pending_file
          pf = @pending_file
          @pending_file = nil
          step = add_step(pf[:event], :attach_image, "magic_attach_image(#{pf[:choice].code}, #{pf[:path_code]})", pf[:choice], extra_review: pf[:review])
          step.event_ids << event["id"]
        else
          add(Step.new(kind: :crop_apply, lines: ["magic_apply_crop"], scopes: scopes_for(event), event_ids: [event["id"]]))
        end
      end

      def finish_pending_file
        return unless @pending_file
        pf = @pending_file
        @pending_file = nil
        args = [pf[:choice].code, pf[:path_code]]
        args << "make_visible: true" if pf[:hidden]
        add_step(pf[:event], :attach_file, "attach_file(#{args.join(", ")})", pf[:choice], extra_review: pf[:review])
      end

      def fixture_path(name)
        rel = File.join(@session.config.fixture_files_dir, name)
        code = "Rails.root.join(#{RubyLiteral.string(rel)})"
        exists = @session.fixture_file_exists?(rel)
        [code, exists ? nil : "add fixture file #{rel} (the recorder cannot read the file the human picked)"]
      end

      def dialog(event)
        target = @steps.reverse.find { |s| s.event_ids.include?(event["trigger_event_id"]) } || @steps.reverse.find { |s| %i[click enter check choose].include?(s.kind) }
        if target
          wrap_last_for_dialog(target, event)
        else
          add(Step.new(kind: :dialog, lines: [], review: "a #{event["dialog_type"]} dialog (#{event["message"].to_s.truncate(60)}) appeared without a recorded trigger", confidence: :red, event_ids: [event["id"]]))
        end
      end

      def hover(event)
        choice = pick(event, kinds: %w[link button link_or_button], allow_css: true)
        finder = case choice.kind
        when "link" then "find_link(#{choice.code})"
        when "button" then "find_button(#{choice.code})"
        when "link_or_button" then "find(:link_or_button, #{choice.code})"
        else "find(#{choice.code})"
        end
        review = event["effect"] ? nil : "hover had no visible effect (nothing opened); consider removing"
        step = add_step(event, :hover, "#{finder}.hover", choice, extra_review: review)
        step.confidence = :amber if step.confidence == :green && !event["effect"]
        step
      end

      def assertion(event)
        a = event["assertion"] || {}
        nil
        step = case a["type"]
        when "content", "no_content"
          text = a["text"].to_s
          index, = i18n_for(event)
          key, = index.best(text)
          code = text_code(text, event)
          line = (a["type"] == "content") ? Assertions.content(code) : Assertions.no_content(code)
          scope = a["scope"]
          scopes = scopes_for(event)
          if scope && scope["css"]
            args = [RubyLiteral.string(scope["css"])]
            args << "text: #{RubyLiteral.string(scope["text"])}" if scope["text"].present?
            scopes << Scope.new(kind: :within, open: "within(#{args.join(", ")}) do", key: "within:#{scope["css"]}:#{scope["text"]}")
          end
          Step.new(kind: :assert, lines: [line], scopes: scopes, event_ids: [event["id"]], confidence: :green, i18n: !!key)
        when "css", "no_css"
          choice = pick(event, kinds: [], allow_css: true)
          line = if a["type"] == "css"
            Assertions.css(choice.code, text_code: a["text"].present? ? RubyLiteral.string(a["text"]) : nil)
          else
            Assertions.no_css(choice.code)
          end
          Step.new(kind: :assert, lines: [line], scopes: scopes_for(event, choice), event_ids: [event["id"]], confidence: choice.confidence, review: choice.review, candidates: choice.alternatives)
        when "field"
          choice = pick(event, kinds: FIELD_KINDS)
          Step.new(kind: :assert, lines: [Assertions.field(choice.code, RubyLiteral.string(a["value"]))], scopes: scopes_for(event, choice), event_ids: [event["id"]], confidence: choice.confidence, review: choice.review)
        when "checked", "unchecked"
          choice = pick(event, kinds: %w[checkbox radio_button])
          Step.new(kind: :assert, lines: [Assertions.checked_field(choice.code, checked: a["type"] == "checked")], scopes: scopes_for(event, choice), event_ids: [event["id"]], confidence: choice.confidence, review: choice.review)
        when "select"
          choice = pick(event, kinds: %w[select])
          Step.new(kind: :assert, lines: [Assertions.select(choice.code, RubyLiteral.string(a["selected"]))], scopes: scopes_for(event, choice), event_ids: [event["id"]], confidence: choice.confidence, review: choice.review)
        when "button"
          choice = pick(event, kinds: %w[button link_or_button], allow_css: false)
          Step.new(kind: :assert, lines: [Assertions.button(choice.code, disabled: a["disabled"])], scopes: scopes_for(event, choice), event_ids: [event["id"]], confidence: choice.confidence, review: choice.review)
        when "link"
          choice = pick(event, kinds: %w[link link_or_button], allow_css: false)
          href = a["href"].present? ? RubyLiteral.string(a["href"]) : nil
          Step.new(kind: :assert, lines: [Assertions.link(choice.code, href_code: href)], scopes: scopes_for(event, choice), event_ids: [event["id"]], confidence: choice.confidence, review: choice.review)
        when "count"
          scope = a["scope"]
          scopes = scopes_for(event)
          if scope && scope["css"]
            scopes << Scope.new(kind: :within, open: "within(#{RubyLiteral.string(scope["css"])}) do", key: "within:#{scope["css"]}")
          end
          Step.new(kind: :assert, lines: [Assertions.css(RubyLiteral.string(a["selector"]), count: a["count"].to_i)], scopes: scopes, event_ids: [event["id"]], confidence: :green)
        when "current_path"
          result = @session.route_resolver.resolve(a["path"].to_s, memoized: @session.memoized)
          code = result.code || RubyLiteral.string(a["path"])
          Step.new(kind: :assert, lines: [Assertions.current_path(code, ignore_query: a["path"].to_s.include?("?"))], event_ids: [event["id"]], confidence: result.code ? :green : :red, review: result.review)
        else
          Step.new(kind: :assert, lines: [], review: "unknown assertion type #{a["type"]}", confidence: :red, event_ids: [event["id"]])
        end
        add(step)
      end
    end
  end
end
