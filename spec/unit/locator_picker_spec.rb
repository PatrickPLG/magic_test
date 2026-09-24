require "rails_helper"

RSpec.describe(MagicTest::Codegen::LocatorPicker) do
  let(:index) { MagicTest::I18nIndex.new(:da) }
  let(:picker) { described_class.new(known_ids: ["42"], i18n_index: index, i18n_keys: true, template_scopes: ["institutions.events.index"]) }

  it "prefers a verified-unique semantic locator and resolves the I18n key (green)" do
    choice = picker.pick([cand(kind: "link_or_button", by: "text", locator: "Opret arrangement")], kinds: %w[link_or_button])
    expect(choice.code).to(eq("I18n.t('events.index.new')"))
    expect(choice.confidence).to(eq(:green))
    expect(choice.i18n_key).to(eq("events.index.new"))
    expect(choice.literal).to(eq("Opret arrangement"))
  end

  it "applies Capybara's smart matching: partial matches count only when there is no exact one" do
    choice = picker.pick([cand(kind: "link_or_button", by: "text", locator: "Gem", exact: 0, partial: 2)], kinds: %w[link_or_button])
    expect(choice.unique).to(be(false))
    choice = picker.pick([cand(kind: "link_or_button", by: "text", locator: "Gem", exact: 1, partial: 3)], kinds: %w[link_or_button])
    expect(choice.unique).to(be(true))
  end

  it "falls back to a scoped candidate (amber) before CSS" do
    choice = picker.pick([
      cand(kind: "link_or_button", by: "text", locator: "Rediger", exact: 3, partial: 3),
      cand(kind: "css", by: "href", locator: "a[href='/x']"),
      cand(kind: "link_or_button", by: "text", locator: "Rediger", exact: 1, partial: 1, scope: {"kind" => "row", "css" => "tr", "text" => "Lead 2"})
    ], kinds: %w[link_or_button])
    expect(choice.confidence).to(eq(:amber))
    expect(choice.scope).to(eq({"kind" => "row", "css" => "tr", "text" => "Lead 2"}))
    expect(choice.code).to(eq("'Rediger'"))
  end

  it "drops dynamic ids and names even when the browser thought them unique" do
    choice = picker.pick([
      cand(kind: "fillable_field", by: "id", locator: "cover_image_discount_42_image"),
      cand(kind: "fillable_field", by: "name", locator: "discount[cover_image]")
    ], kinds: %w[fillable_field])
    expect(choice.code).to(eq("'discount[cover_image]'"))
  end

  it "uses CSS (amber) and positional (red, reviewed) as last resorts" do
    css = picker.pick([cand(kind: "css", by: "classes", locator: "button.js-star", scope: {"kind" => "row", "css" => "tr", "text" => "Lead 2"})], kinds: [])
    expect(css.confidence).to(eq(:amber))
    pos = picker.pick([cand(kind: "positional", by: "positional", locator: "td:nth-of-type(4) > button:nth-of-type(2)", scope: {"kind" => "row", "css" => "tr", "text" => "Lead 2"})], kinds: [])
    expect(pos.confidence).to(eq(:red))
    expect(pos.review).to(include("positional selector"))
  end

  it "keeps a literal with a REVIEW when several I18n keys render the same text" do
    choice = described_class.new(known_ids: [], i18n_index: index, i18n_keys: true).pick([cand(kind: "fillable_field", by: "label", locator: "Navn")], kinds: %w[fillable_field])
    expect(choice.code).to(eq("'Navn'"))
    expect(choice.review).to(include("several I18n keys"))
    expect(choice.confidence).to(eq(:amber))
  end

  it "honours the literal-text toggle" do
    choice = picker.pick([cand(kind: "link_or_button", by: "text", locator: "Opret arrangement")], kinds: %w[link_or_button], i18n: false)
    expect(choice.code).to(eq("'Opret arrangement'"))
  end

  it "returns a red review when nothing is unique" do
    choice = picker.pick([cand(kind: "link_or_button", by: "text", locator: "Rediger", exact: 3, partial: 3)], kinds: %w[link_or_button], allow_css: false)
    expect(choice.confidence).to(eq(:red))
    expect(choice.review).to(include("matches 3 elements"))
  end
end
