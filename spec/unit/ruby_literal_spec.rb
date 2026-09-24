require "spec_helper"
require "magic_test/ruby_literal"

RSpec.describe(MagicTest::RubyLiteral) do
  describe ".string" do
    it "uses single quotes when nothing needs escaping" do
      expect(described_class.string("Gem arrangement")).to(eq("'Gem arrangement'"))
      expect(described_class.string("æøå ÆØÅ")).to(eq("'æøå ÆØÅ'"))
      expect(described_class.string("  hej ")).to(eq("'  hej '"))
      expect(described_class.string("")).to(eq("''"))
    end

    it "switches to double quotes for apostrophes, backslashes, newlines and interpolation" do
      expect(described_class.string("Studiz' vilkår")).to(eq("\"Studiz' vilkår\""))
      expect(described_class.string("a\\b")).to(eq("\"a\\\\b\""))
      expect(described_class.string("Linje 1\nLinje 2")).to(eq("\"Linje 1\\nLinje 2\""))
      expect(described_class.string("pris: \#{x}")).to(eq("'pris: \#{x}'")) # single quotes never interpolate
      expect(described_class.string("tab\there")).to(eq("\"tab\\there\""))
    end

    it "always round-trips through Ruby" do
      ["it's", "a\\b", "x\r\ny", "\"quoted\"", "'both' \"kinds\"", "\u0000nul", "æøå'"].each do |value|
        expect(eval(described_class.string(value))).to(eq(value)) # rubocop:disable Security/Eval
      end
    end
  end

  describe ".kwargs and .value" do
    it "renders keyword arguments" do
      expect(described_class.kwargs(with: "x", count: 2, exact: true)).to(eq("with: 'x', count: 2, exact: true"))
    end

    it "passes raw code through untouched" do
      raw = described_class.raw("I18n.t('nav.events')")
      expect(described_class.locator(raw)).to(eq("I18n.t('nav.events')"))
      expect(described_class.locator("Arrangementer")).to(eq("'Arrangementer'"))
    end

    it "renders symbols, numbers, arrays and hashes" do
      expect(described_class.value(:enter)).to(eq(":enter"))
      expect(described_class.value([1, "a"])).to(eq("[1, 'a']"))
      expect(described_class.value(nil)).to(eq("nil"))
    end
  end
end
