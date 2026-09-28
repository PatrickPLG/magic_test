require "rails_helper"

RSpec.describe(MagicTest::DbChanges) do
  it "parses INSERT/UPDATE/DELETE statements with any quoting" do
    expect(described_class.parse('INSERT INTO "events_events" ("name") VALUES (?)')).to(eq([:insert, "events_events"]))
    expect(described_class.parse("UPDATE `discounts` SET name_da = ?")).to(eq([:update, "discounts"]))
    expect(described_class.parse("DELETE FROM leads WHERE id = 1")).to(eq([:delete, "leads"]))
    expect(described_class.parse('SELECT * FROM "users"')).to(be_nil)
    expect(described_class.parse("begin transaction")).to(be_nil)
  end

  # B8 (1.2): the statements Postgres emits (bind params, RETURNING, a schema
  # prefix, query-log comments, CTEs) must parse like SQLite's.
  it "parses the statement shapes Postgres emits" do
    expect(described_class.parse('UPDATE "discounts" SET "archived" = $1, "updated_at" = $2 WHERE "discounts"."id" = $3')).to(eq([:update, "discounts"]))
    expect(described_class.parse('INSERT INTO "discounts" ("name_da", "created_at") VALUES ($1, $2) RETURNING "id"')).to(eq([:insert, "discounts"]))
    expect(described_class.parse('UPDATE "public"."discounts" SET "archived" = $1 WHERE "discounts"."id" = $2')).to(eq([:update, "discounts"]))
    expect(described_class.parse('DELETE FROM "public"."discounts" WHERE "discounts"."id" = $1')).to(eq([:delete, "discounts"]))
    expect(described_class.parse('/*application:Studiz,controller:discounts,action:archive*/ UPDATE "discounts" SET "archived" = $1')).to(eq([:update, "discounts"]))
    expect(described_class.parse('UPDATE "discounts" SET "archived" = $1 /*application:Studiz*/')).to(eq([:update, "discounts"]))
    expect(described_class.parse("update discounts set archived = true where id = 2")).to(eq([:update, "discounts"]))
    expect(described_class.parse('INSERT INTO "discounts" ("id") VALUES ($1) ON CONFLICT ("id") DO UPDATE SET "archived" = excluded."archived"')).to(eq([:insert, "discounts"]))
    expect(described_class.parse('WITH "recent" AS (SELECT "id" FROM "discounts") UPDATE "discounts" SET "archived" = $1')).to(eq([:update, "discounts"]))
    expect(described_class.parse('SELECT "discounts".* FROM "discounts" WHERE "discounts"."id" = $1 LIMIT $2')).to(be_nil)
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

  # B8 (1.2): on the real app an UPDATE run by a rails-ujs remote link produced
  # no suggestion. Two reasons a request can be skipped: it is a GET (Studiz's
  # archive confirm is a remote GET link), and it carries no form params (the
  # reload suggestion used to compare params only).
  describe "changes made by requests without form params" do
    let(:provider) { create(:provider, :with_cvr) }
    let(:discount) { create(:discount, provider: provider, name_da: "Kaffe 20%") }

    def archive_request(method)
      Discount.where(id: discount.id).update_all(archived: true) # the server changed the row; the memoised object still says false
      MagicTest::RequestRecord.new(at: 1.0, started_at: 0.5, method: method, path: "/udbydere/#{provider.id}/admin/rabatter/#{discount.id}/archive_now",
        fullpath: "/udbydere/#{provider.id}/admin/rabatter/#{discount.id}/archive_now", status: 200, params: {}, templates: [],
        db_changes: described_class.summarise([[:update, "discounts"]]).map(&:to_h), record_ids: [provider.id.to_s, discount.id.to_s], xhr: true, html: false)
    end

    def suggestions_for(method)
      session = FakeSession.new(known_ids: [provider.id.to_s, discount.id.to_s], memoized: {provider: provider, discount: discount})
      session.request_log.add(archive_request(method))
      _steps, suggestions = session.build([ev("click", target: target(tag: "a", text: "Arkiver nu"), candidates: [cand(kind: "link_or_button", locator: "Arkiver nu")])])
      suggestions.flat_map(&:lines)
    end

    it "suggests the changed attribute of the memoised record after a mutating GET (remote link)" do
      expect(suggestions_for("GET")).to(include("expect(discount.reload.archived).to(eq(true))"))
    end

    it "suggests it after a POST without form params too, by diffing the memoised record" do
      expect(suggestions_for("POST")).to(include("expect(discount.reload.archived).to(eq(true))"))
    end
  end
end
