require "monitor"

module MagicTest
  # Ordered, thread-safe log of intent events posted by the browser. Events
  # are deduplicated by their client-generated id (the client retries and
  # replays a sessionStorage buffer after navigation).
  class EventLog
    include MonitorMixin

    def initialize
      super
      @events = []
      @ids = {}
      @listeners = []
    end

    def add(event)
      synchronize do
        id = event["id"] || event[:id]
        return false if id && @ids[id]
        @ids[id] = true if id
        @events << event
        @events.sort_by! { |e| [e["ts"].to_f, e["seq"].to_i] }
        true
      end
    end

    def add_all(events)
      Array(events).map { |e| add(e) }
    end

    def all
      synchronize { @events.dup }
    end

    def clear
      synchronize do
        @events.clear
        @ids.clear
      end
    end

    def delete(id)
      synchronize do
        @events.reject! { |e| e["id"] == id }
      end
    end

    def size
      synchronize { @events.size }
    end

    def find(id)
      synchronize { @events.find { |e| e["id"] == id } }
    end

    def update(id)
      synchronize do
        event = @events.find { |e| e["id"] == id }
        yield event if event
        event
      end
    end
  end
end
