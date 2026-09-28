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

  # B7 (1.2): on the real app the recorder wrote click_on('Halv Pris Rabat
  # Beskrivelse af rabat') and rejected #discount-card-42 as dynamic. Values
  # and ids that belong to the example's records are emitted through the lets.
  describe "record-based locators" do
    let(:discount) { Struct.new(:id, :name_da, :description).new(42, "Kaffe 10%", "Beskrivelse af rabat") }
    let(:provider) { Struct.new(:id, :name).new(7, "Café Vivaldi 3") }
    let(:refs) { MagicTest::RecordRefs.new({"discount" => discount, "provider" => provider}) }
    let(:picker) { described_class.new(known_ids: %w[42 7], i18n_index: index, i18n_keys: true, record_refs: refs) }

    it "keeps an id that embeds a known record id, interpolating the let" do
      choice = picker.pick([
        cand(kind: "css", by: "id", locator: "#discount-card-42"),
        cand(kind: "css", by: "classes", locator: ".card.deal", text: "Kaffe 10% Beskrivelse af rabat")
      ], kinds: [])
      expect(choice.code).to(eq("\"#discount-card-\#{discount.id}\""))
      expect(choice.confidence).to(eq(:amber))
      expect(choice.review).to(be_nil)
    end

    it "still drops an id whose number could be any of several records" do
      refs = MagicTest::RecordRefs.new({"discount" => discount, "other" => Struct.new(:id).new(42)})
      picker = described_class.new(known_ids: %w[42], i18n_index: index, record_refs: refs)
      choice = picker.pick([cand(kind: "css", by: "id", locator: "#row-42"), cand(kind: "css", by: "classes", locator: "tr.lead")], kinds: [])
      expect(choice.code).to(eq("'tr.lead'"))
    end

    it "emits the let's attribute when a link or button text is a record value" do
      choice = picker.pick([cand(kind: "link_or_button", by: "text", locator: "Kaffe 10%")], kinds: %w[link_or_button])
      expect(choice.code).to(eq("discount.name_da"))
      expect(choice.literal).to(eq("Kaffe 10%"))
      expect(choice.confidence).to(eq(:green))
      expect(choice.i18n_key).to(be_nil)
    end

    it "uses the let's attribute in a text: filter and carries it into a within scope" do
      choice = picker.pick([cand(kind: "css", by: "classes", locator: ".card.deal", text: "Kaffe 10%")], kinds: [])
      expect(choice.code).to(eq("'.card.deal', text: discount.name_da"))
      scoped = picker.pick([
        cand(kind: "link_or_button", by: "text", locator: "Rediger", exact: 2, partial: 2),
        cand(kind: "link_or_button", by: "text", locator: "Rediger", exact: 1, partial: 1, scope: {"kind" => "row", "css" => ".deal", "text" => "Kaffe 10%"})
      ], kinds: %w[link_or_button])
      expect(scoped.scope).to(eq({"kind" => "row", "css" => ".deal", "text" => "Kaffe 10%", "text_code" => "discount.name_da"}))
    end

    it "keeps the value a record had when first seen, even after the recorder reloads it with a new value" do
      refs = MagicTest::RecordRefs.new({"discount" => discount})
      discount.name_da = "Kaffe 25%" # what `discount.reload` does after the rename step
      refs.add({"discount" => discount, "provider" => provider})
      expect(refs.expression_for_value("Kaffe 10%")).to(eq("discount.name_da"))
      expect(refs.expression_for_value("Kaffe 25%")).to(be_nil)
      expect(refs.expression_for_value("Café Vivaldi 3")).to(eq("provider.name"))
    end

    it "prefers the record wrapper (an ancestor id embedding the record id) and writes it through the let" do
      choice = picker.pick([
        cand(kind: "css", by: "classes", locator: "div.card-body", exact: 2, partial: 2),
        cand(kind: "css", by: "classes", locator: "div.card-body", exact: 1, partial: 1, scope: {"kind" => "heading", "css" => "div.card.deal", "text" => "Kaffe 10%"}),
        cand(kind: "css", by: "classes", locator: "div.card-body", exact: 1, partial: 1, scope: {"kind" => "record", "css" => "#discount-card-42"})
      ], kinds: [])
      expect(choice.scope).to(eq({"kind" => "record", "css" => "#discount-card-42", "css_code" => "\"#discount-card-\#{discount.id}\""}))
      seen_in_requests = described_class.new(known_ids: %w[42 7 99], i18n_index: index, record_refs: refs) # 99 was in a request, but no let has it
      dropped = seen_in_requests.pick([cand(kind: "css", by: "classes", locator: "div.card-body", exact: 1, partial: 1, scope: {"kind" => "record", "css" => "#row-99"})], kinds: [])
      expect(dropped.unique).to(be(false)) # the wrapper is dynamic, not a locator
    end

    it "flags text that merely contains factory data when nothing stabler is available" do
      choice = picker.pick([cand(kind: "css", by: "classes", locator: ".card.deal", text: "Kaffe 10% Beskrivelse af rabat")], kinds: [])
      expect(choice.code).to(eq("'.card.deal', text: 'Kaffe 10% Beskrivelse af rabat'"))
      expect(choice.review).to(eq("the text contains factory data (discount.name_da, discount.description); prefer a stable id or data attribute on the element"))
    end
  end
end
