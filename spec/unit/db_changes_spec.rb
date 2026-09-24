require "rails_helper"

RSpec.describe(MagicTest::DbChanges) do
  it "parses INSERT/UPDATE/DELETE statements with any quoting" do
    expect(described_class.parse('INSERT INTO "events_events" ("name") VALUES (?)')).to(eq([:insert, "events_events"]))
    expect(described_class.parse("UPDATE `discounts` SET name_da = ?")).to(eq([:update, "discounts"]))
    expect(described_class.parse("DELETE FROM leads WHERE id = 1")).to(eq([:delete, "leads"]))
    expect(described_class.parse('SELECT * FROM "users"')).to(be_nil)
    expect(described_class.parse("begin transaction")).to(be_nil)
  end

  it "maps tables to models, including namespaced ones" do
    expect(described_class.model_for("events_events")).to(eq(Events::Event))
    expect(described_class.model_for("institutions_employees")).to(eq(Institutions::Employee))
    expect(described_class.model_for("discounts")).to(eq(Discount))
    expect(described_class.model_for("schema_migrations")).to(be_nil)
    expect(described_class.model_for("no_such_table")).to(be_nil)
  end

  describe "ignored tables" do
    # Real models for tables that only exist in Studiz, so the test proves the
    # ignore list is what drops them, not a missing model.
    before do
      stub_const("Audit", Class.new(ActiveRecord::Base) { self.table_name = "audits" })
      stub_const("LiveSupport::Ping", Class.new(ActiveRecord::Base) { self.table_name = "live_support_pings" })
      described_class.instance_variable_set(:@models, {})
    end

    after do
      MagicTest.config.ignored_tables = []
      described_class.instance_variable_set(:@models, {})
    end

    it "ignores auditing, Ahoy, Flipper and live-support tables by default" do
      %w[audits ahoy_visits ahoy_events flipper_features flipper_gates live_support_pings live_support_conversations].each do |table|
        expect(MagicTest.config.ignored_table?(table)).to(be(true), table)
        expect(described_class.model_for(table)).to(be_nil, table)
      end
      changes = described_class.summarise([[:insert, "audits"], [:insert, "live_support_pings"], [:update, "flipper_gates"], [:insert, "discounts"]])
      expect(changes.map(&:table)).to(eq(["discounts"]))
    end

    it "merges configured tables (strings or regexps) with the defaults" do
      MagicTest.config.ignored_tables = ["discounts", /\Aevents_/]
      expect(MagicTest.config.ignored_tables).to(include("audits", "ahoy_visits", "discounts"))
      expect(described_class.model_for("discounts")).to(be_nil)
      expect(described_class.model_for("events_events")).to(be_nil)
      expect(described_class.model_for("leads")).to(eq(Lead))

      MagicTest.config.ignored_tables << "leads"
      expect(described_class.model_for("leads")).to(be_nil)

      MagicTest.config.ignored_tables = []
      expect(MagicTest.config.ignored_tables).to(eq(MagicTest::Configuration::DEFAULT_IGNORED_TABLES))
      expect(described_class.model_for("discounts")).to(eq(Discount))
    end

    it "never produces DB-change suggestions for ignored tables" do
      MagicTest.config.ignored_tables = ["leads"]
      session = FakeSession.new
      changes = described_class.summarise([[:insert, "audits"], [:insert, "live_support_pings"], [:insert, "leads"], [:insert, "discounts"]])
      session.request_log.add(MagicTest::RequestRecord.new(at: 1.0, started_at: 0.5, method: "POST", path: "/x", fullpath: "/x", status: 302,
        params: {}, templates: [], db_changes: changes.map(&:to_h), record_ids: [], xhr: false, html: false))
      _steps, suggestions = session.build([ev("click", target: target(tag: "a", text: "Gem"), candidates: [cand(kind: "link_or_button", locator: "Gem")])])
      codes = suggestions.flat_map(&:lines)
      expect(codes).to(include("expect(Discount.count).to(eq(#{Discount.count}))"))
      expect(codes.grep(/Audit|LiveSupport|Lead/)).to(be_empty)
    end
  end

  it "summarises with counts" do
    changes = described_class.summarise([[:insert, "events_events"], [:insert, "events_events"], [:update, "users"], [:insert, "sessions"]])
    expect(changes.map(&:to_h)).to(contain_exactly(
      {operation: :insert, table: "events_events", model: "Events::Event", count: 2},
      {operation: :update, table: "users", model: "User", count: 1}
    ))
  end
end
