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

  it "summarises with counts" do
    changes = described_class.summarise([[:insert, "events_events"], [:insert, "events_events"], [:update, "users"], [:insert, "sessions"]])
    expect(changes.map(&:to_h)).to(contain_exactly(
      {operation: :insert, table: "events_events", model: "Events::Event", count: 2},
      {operation: :update, table: "users", model: "User", count: 1}
    ))
  end
end
