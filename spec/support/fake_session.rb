# A stand-in for MagicTest::Session in codegen unit specs: just the collaborators
# the Builder reads.
class FakeSession
  attr_reader :request_log, :memoized, :config
  attr_accessor :i18n_keys, :known_ids, :fixture_files

  def initialize(known_ids: [], i18n_keys: true, memoized: {}, locale: :da, fixture_files: [])
    @known_ids = known_ids
    @i18n_keys = i18n_keys
    @memoized = memoized
    @request_log = MagicTest::RequestLog.new
    @config = MagicTest::Configuration.new
    @locale = locale
    @fixture_files = fixture_files
  end

  def i18n_keys?
    @i18n_keys
  end

  def i18n_index(locale = nil)
    @i18n_indexes ||= {}
    @i18n_indexes[(locale || @locale).to_sym] ||= MagicTest::I18nIndex.new(locale || @locale)
  end

  def route_resolver
    @route_resolver ||= MagicTest::RouteResolver.new
  end

  def fixture_file_exists?(relative)
    @fixture_files.include?(relative)
  end

  def build(events, overrides: {})
    MagicTest::Codegen::Builder.new(events, session: self, overrides: overrides).build
  end

  def lines(events, overrides: {})
    steps, = build(events, overrides: overrides)
    MagicTest::Codegen::Emitter.new(steps).render
  end
end

module EventFactory
  # A candidate as the browser reports it.
  def cand(kind:, locator:, by: "text", exact: 1, partial: 1, scope: nil, text: nil)
    {"kind" => kind, "by" => by, "locator" => locator, "exact" => exact, "partial" => partial, "scope" => scope, "text" => text, "unique" => exact == 1 || (exact.zero? && partial == 1)}
  end

  def ev(kind, **attrs)
    @seq = (@seq || 0) + 1
    {"id" => "e-#{@seq}", "seq" => @seq, "ts" => @seq * 10, "kind" => kind, "url" => "/", "window" => {"id" => "main"}, "frame" => nil}.merge(attrs.transform_keys(&:to_s))
  end

  def target(tag: "a", text: nil, id: nil, name: nil, role: nil)
    {"tag" => tag, "text" => text, "id" => id, "name" => name, "fingerprint" => [tag, id, name, text].join("|"), "role" => role}
  end
end

RSpec.configure do |config|
  config.include EventFactory
end
