require "rails_helper"

RSpec.describe(MagicTest::I18nIndex) do
  let(:index) { described_class.new(:da) }

  it "maps rendered text back to keys" do
    expect(index.lookup("Alle arrangementer").map(&:key)).to(eq(["events.index.title"]))
    expect(index.lookup("Opret arrangement").map(&:key)).to(eq(["events.index.new"]))
  end

  it "indexes what I18n.t returns, so the last duplicate activerecord block wins" do
    expect(I18n.t("activerecord.attributes.discount.name_da")).to(eq("Rabatnavn"))
    expect(index.lookup("Rabatnavn").map(&:key)).to(include("activerecord.attributes.discount.name_da"))
    expect(index.lookup("Navn").map(&:key)).not_to(include("activerecord.attributes.discount.name_da"))
  end

  it "indexes simple_form labels, activerecord attributes and submit helpers" do
    expect(index.lookup("Fortæl om dig selv").map(&:key)).to(eq(["simple_form.labels.student.bio"]))
    expect(index.lookup("Gem arrangement").map(&:key)).to(match_array(%w[helpers.submit.events_event.create helpers.submit.events_event.update]))
    expect(index.lookup("Kontonummer").map(&:key)).to(eq(["activerecord.attributes.events/event.account_number"]))
  end

  it "normalises whitespace and ignores the required mark" do
    expect(index.lookup("  Alle   arrangementer ").map(&:key)).to(eq(["events.index.title"]))
    _, matches = index.best("* Navn")
    expect(matches.map(&:key)).to(include("activerecord.attributes.events/event.name"))
    best, = index.best("* Kontonummer")
    expect(best.key).to(eq("activerecord.attributes.events/event.account_number"))
  end

  it "reports ambiguity and resolves it by template scope" do
    best, matches = index.best("Navn")
    expect(best).to(be_nil)
    expect(matches.map(&:key)).to(include("activerecord.attributes.events/event.name", "activerecord.attributes.student_organisation_membership.name"))
    best, = index.best("Rediger", scopes: ["backoffice.leads.index"])
    expect(best.key).to(eq("leads.index.edit"))
    best, = index.best("Rediger", scopes: ["providers.admin.discounts.index"])
    expect(best.key).to(eq("discounts.index.edit"))
  end

  it "matches interpolated translations and recovers the values" do
    match = index.lookup("Velkommen, Mette").first
    expect(match.key).to(eq("home.index.welcome"))
    expect(match.interpolations).to(eq({"name" => "Mette"}))
    match = index.lookup("Opret Rabat").first
    expect(match.key).to(eq("helpers.submit.create"))
  end

  it "returns nothing for unknown text" do
    expect(index.lookup("Nothing like this")).to(eq([]))
    expect(index.best("")).to(eq([nil, []]))
  end

  it "builds an English index too" do
    expect(described_class.new(:en).lookup("All events").map(&:key)).to(eq(["events.index.title"]))
  end
end
