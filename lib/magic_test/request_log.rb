require "monitor"

module MagicTest
  # What the middleware saw for one request: enough to generate `visit`,
  # `have_current_path`, flash and DB-change suggestions and to feed record
  # ids into the dynamic-value detector.
  RequestRecord = Struct.new(
    :id, :at, :method, :path, :fullpath, :status, :location, :content_type,
    :params, :user, :flash, :templates, :db_changes, :record_ids, :xhr, :html, :locale, :started_at, :deliveries, :enqueued_jobs
  ) do
    def html?
      html
    end

    def redirect?
      (300..399).cover?(status.to_i) && location.present?
    end

    def get?
      method == "GET"
    end

    # `app/views/backoffice/leads/index.html.haml` → `backoffice.leads.index`
    # (the lazy-lookup scope). Gem templates (absolute paths) carry no
    # application I18n scope and are skipped.
    def template_scopes
      Array(templates).reject { |t| t.start_with?("/") }
        .map { |t| t.sub(/\.[^.]+\z/, "").sub(/\.[^.]+\z/, "").tr("/", ".").sub("._", ".") }.uniq
    end

    # Request start (seconds); events that happened before it belong to the
    # previous page. Falls back to the completion time for old records.
    def started_at
      self[:started_at] || at
    end
  end

  class RequestLog
    include MonitorMixin

    def initialize
      super
      @records = []
      @seq = 0
    end

    def add(record)
      synchronize do
        @seq += 1
        record.id = @seq
        @records << record
        record
      end
    end

    def all
      synchronize { @records.dup }
    end

    def clear
      synchronize { @records.clear }
    end

    def since(id)
      synchronize { @records.select { |r| r.id > id.to_i } }
    end

    def last
      synchronize { @records.last }
    end

    # Every integer that showed up in a path segment or a param value.
    def record_ids
      synchronize { @records.flat_map { |r| r.record_ids || [] }.uniq }
    end

    def html_page_loads
      synchronize { @records.select { |r| r.get? && r.html? && !r.xhr } }
    end
  end
end
