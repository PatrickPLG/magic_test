module MagicTest
  module Codegen
    # One generated step: the Ruby lines it renders to (unindented), the scope
    # chain it lives in, an optional dialog wrapper, and review metadata for
    # the toolbar (confidence badge, alternatives, comments).
    class Step
      CONFIDENCE = %i[green amber red].freeze

      attr_accessor :id, :kind, :lines, :scopes, :wrapper, :confidence, :review, :candidates,
        :event_ids, :locator, :i18n, :meta, :suggestion

      def initialize(kind:, lines:, id: nil, scopes: [], wrapper: nil, confidence: :green, review: nil,
        candidates: [], event_ids: [], locator: nil, i18n: true, meta: {}, suggestion: false)
        @kind = kind
        @lines = Array(lines)
        @id = id || self.class.stable_id(kind, Array(event_ids), @lines, suggestion)
        @scopes = scopes
        @wrapper = wrapper
        @confidence = confidence
        @review = review
        @candidates = candidates
        @event_ids = Array(event_ids)
        @locator = locator
        @i18n = i18n
        @meta = meta
        @suggestion = suggestion
      end

      # Stable across rebuilds (the toolbar and the scripted human refer to
      # steps by id between two state polls).
      def self.stable_id(kind, event_ids, lines, suggestion)
        require "digest"
        seed = [kind, event_ids.join(","), suggestion ? lines.join("\n") : ""].join("|")
        "#{suggestion ? "g" : "s"}-#{Digest::MD5.hexdigest(seed)[0, 10]}"
      end

      def review_comment
        return nil if review.blank?
        "# magic_test: REVIEW #{review}"
      end

      # Lines including the review comment, still unindented and unscoped.
      def body_lines
        review_comment ? [review_comment] + lines : lines
      end

      def to_h
        {
          "id" => id, "kind" => kind.to_s, "code" => Emitter.new([self]).render.join("\n"),
          "lines" => lines, "confidence" => confidence.to_s, "review" => review,
          "candidates" => candidates, "event_ids" => event_ids, "locator" => locator,
          "i18n" => i18n, "scopes" => scopes.map(&:to_h), "wrapper" => wrapper&.to_h,
          "suggestion" => suggestion
        }
      end
    end

    # `within('#ajax-modal') do`, `within_frame('preview') do`, `within_window(new_window) do`
    Scope = Struct.new(:kind, :open, :key) do
      def to_h
        {"kind" => kind.to_s, "open" => open, "key" => key}
      end

      def ==(other)
        other.is_a?(Scope) && other.key == key
      end
      alias_method :eql?, :==

      def hash
        key.hash
      end
    end

    # `accept_confirm('…') do` around one step.
    Wrapper = Struct.new(:open) do
      def to_h
        {"open" => open}
      end
    end
  end
end
