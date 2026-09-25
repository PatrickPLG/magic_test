module MagicTest
  # Injects the recorder script into every HTML response and records what the
  # server saw for each request (path, params, status, redirect, Warden user,
  # flash, rendered templates, SQL writes, record ids). Active only when
  # MagicTest.enabled?.
  class Middleware
    SCRIPT_TAG = %(<script src="/__magic_test/recorder.js" defer data-magic-test="recorder"></script>)
    HEAD_CLOSE = %r{</head\s*>}i
    BODY_CLOSE = %r{</body\s*>}i

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) if env["PATH_INFO"].to_s.start_with?("/__magic_test")

      request = Rack::Request.new(env)
      collector = RequestCollector.new
      started_at = Time.now.to_f
      jobs_before = sidekiq_job_counts
      Thread.current[:magic_test_request] = collector
      session_flash = flash_before(env)
      status, headers, body = @app.call(env)
      record = build_record(request, status, headers, collector, session_flash, env)
      if record
        record.started_at = started_at
        record.deliveries = collector.deliveries
        record.enqueued_jobs = enqueued_since(jobs_before)
      end
      (MagicTest.session&.request_log || MagicTest.pre_session_request_log).add(record) if record && !ignored_path?(request.path)
      if injectable?(request, status, headers)
        body, headers = inject(body, headers)
      end
      [status, headers, body]
    ensure
      Thread.current[:magic_test_request] = nil
    end

    # Installed once at boot (under MAGIC_TEST); attributes notifications to
    # the request running on the current thread.
    def self.subscribe!
      return if @subscribed
      @subscribed = true
      ActiveSupport::Notifications.subscribe(/render_(template|partial)\.action_view/) do |_name, _s, _f, _id, payload|
        collector = Thread.current[:magic_test_request]
        next unless collector
        identifier = payload[:identifier].to_s
        root = defined?(Rails) ? "#{Rails.root}/app/views/" : nil
        collector.templates << ((root && identifier.start_with?(root)) ? identifier.sub(root, "") : identifier)
      end
      ActiveSupport::Notifications.subscribe("deliver.action_mailer") do |_name, _s, _f, _id, payload|
        collector = Thread.current[:magic_test_request]
        next unless collector
        collector.deliveries << {"to" => Array(payload[:to]).map(&:to_s), "subject" => payload[:subject].to_s, "mailer" => payload[:mailer].to_s}
      end
      ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _s, _f, _id, payload|
        collector = Thread.current[:magic_test_request]
        next unless collector
        parsed = DbChanges.parse(payload[:sql])
        collector.sql << parsed if parsed
      end
    end

    private

    def ignored_path?(path)
      MagicTest.config.ignored_request_paths.any? { |re| re.match?(path) }
    end

    def flash_before(env)
      session = env["rack.session"]
      return nil unless session.respond_to?(:[])
      flash = session["flash"]
      flash = flash["flashes"] if flash.is_a?(Hash) && flash.key?("flashes")
      flash.is_a?(Hash) ? flash.dup : nil
    rescue
      nil
    end

    def build_record(request, status, headers, collector, session_flash, env)
      flash = env["action_dispatch.request.flash_hash"]&.to_hash
      flash = session_flash if flash.blank? && session_flash.present?
      params = filtered_params(env)
      RequestRecord.new(
        at: Time.now.to_f, method: request.request_method, path: request.path, fullpath: request.fullpath,
        status: status.to_i, location: headers["Location"] || headers["location"], content_type: headers["Content-Type"] || headers["content-type"],
        params: params, user: warden_user(env), flash: flash.presence, templates: collector.templates,
        db_changes: DbChanges.summarise(collector.sql).map(&:to_h), record_ids: record_ids(request.path, params),
        xhr: request.xhr? || request.get_header("HTTP_ACCEPT").to_s.include?("javascript"),
        html: (headers["Content-Type"] || headers["content-type"]).to_s.include?("text/html"),
        locale: env["action_dispatch.request.path_parameters"]&.dig(:locale)&.to_s
      )
    rescue => e
      MagicTest.logger.warn("magic_test: request record failed: #{e.class}: #{e.message}")
      nil
    end

    def filtered_params(env)
      raw = env["action_dispatch.request.parameters"] || {}
      filter = env["action_dispatch.parameter_filter"]
      params = raw.to_h.except("controller", "action", "authenticity_token", "utf8", "commit", "_method")
      params = ActiveSupport::ParameterFilter.new(filter).filter(params) if filter && defined?(ActiveSupport::ParameterFilter)
      deep_stringify(params)
    end

    def deep_stringify(obj)
      case obj
      when Hash then obj.to_h { |k, v| [k.to_s, deep_stringify(v)] }
      when Array then obj.map { |v| deep_stringify(v) }
      when ActionDispatch::Http::UploadedFile then obj.original_filename
      else obj.respond_to?(:original_filename) ? obj.original_filename : obj
      end
    end

    def warden_user(env)
      warden = env["warden"]
      return nil unless warden
      user = warden.user
      return nil unless user
      {"class" => user.class.name, "id" => user.id, "role_type" => user.try(:role_type), "role_id" => user.try(:role_id)}
    rescue
      nil
    end

    def record_ids(path, params)
      ids = path.scan(%r{/(\d+)(?=/|\z)}).flatten
      ids += numeric_values(params)
      ids.uniq
    end

    def numeric_values(obj)
      case obj
      when Hash then obj.values.flat_map { |v| numeric_values(v) }
      when Array then obj.flat_map { |v| numeric_values(v) }
      when String then obj.match?(/\A\d{1,12}\z/) ? [obj] : []
      when Integer then [obj.to_s]
      else []
      end
    end

    def injectable?(request, status, headers)
      status_ok = status.to_i == 200 || (400...600).cover?(status.to_i)
      return false unless status_ok
      type = (headers["Content-Type"] || headers["content-type"]).to_s
      type.include?("text/html") && !request.xhr?
    end

    def inject(body, headers)
      html = +""
      body.each { |part| html << part.to_s }
      body.close if body.respond_to?(:close)
      injected = if HEAD_CLOSE.match?(html)
        html.sub(HEAD_CLOSE) { |m| "#{SCRIPT_TAG}\n#{m}" }
      elsif BODY_CLOSE.match?(html)
        html.sub(BODY_CLOSE) { |m| "#{SCRIPT_TAG}\n#{m}" }
      else
        html + SCRIPT_TAG
      end
      headers = headers.dup
      headers["Content-Length"] = injected.bytesize.to_s if headers.key?("Content-Length") || headers.key?("content-length")
      headers.delete("content-length") if headers.key?("Content-Length") && headers.key?("content-length")
      [[injected], headers]
    end

    # Sidekiq (faked in specs) queues per worker class, to see what a request enqueued.
    def sidekiq_job_counts
      return {} unless defined?(Sidekiq::Testing) && Sidekiq::Testing.respond_to?(:fake?) && Sidekiq::Testing.fake?
      Sidekiq::Queues.jobs_by_queue.values.flatten.group_by { |j| j["class"].to_s }.transform_values(&:size)
    rescue => e
      MagicTest.logger.warn("magic_test: sidekiq job count failed: #{e.message}")
      {}
    end

    def enqueued_since(before)
      after = sidekiq_job_counts
      after.filter_map { |klass, n| (n - before.fetch(klass, 0)).positive? ? {"class" => klass, "count" => n - before.fetch(klass, 0)} : nil }
    end

    # Per-request buffer filled by ActiveSupport::Notifications subscribers.
    class RequestCollector
      attr_reader :templates, :sql, :deliveries

      def initialize
        @templates = []
        @sql = []
        @deliveries = []
      end
    end
  end
end
