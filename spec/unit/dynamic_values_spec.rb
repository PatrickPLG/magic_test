require "spec_helper"
require "active_support/all"
require "magic_test/dynamic_values"

RSpec.describe(MagicTest::DynamicValues) do
  let(:known) { %w[42 17 3] }

  describe ".dynamic?" do
    it "rejects ids that embed a record id seen in the session" do
      expect(described_class.dynamic?("discount-card-42", known)).to(be(true))
      expect(described_class.dynamic?("invoice_17", known)).to(be(true))
      expect(described_class.dynamic?("cover_image_discount_42_image", known)).to(be(true))
      expect(described_class.dynamic?("student_3", known)).to(be(true))
    end

    it "accepts stable Rails ids and names" do
      expect(described_class.dynamic?("events_event_name", known)).to(be(false))
      expect(described_class.dynamic?("discount_name_da", known)).to(be(false))
      expect(described_class.dynamic?("events_event[name]", known)).to(be(false))
      expect(described_class.dynamic?("discount-list", known)).to(be(false))
      expect(described_class.dynamic?("col-md-6", known)).to(be(false))
    end

    it "rejects nested-attribute indices, epoch timestamps, Trix counters, uuids and placeholders" do
      expect(described_class.dynamic?("events_event_ticket_types_attributes_0_name", [])).to(be(true))
      expect(described_class.dynamic?("events_event[ticket_types_attributes][1695551234567][name]", [])).to(be(true))
      expect(described_class.dynamic?("field_1695551234567", [])).to(be(true))
      expect(described_class.dynamic?("trix_input_3", [])).to(be(true))
      expect(described_class.dynamic?("trix-input-12", [])).to(be(true))
      expect(described_class.dynamic?("3f2504e0-4f89-11d3-9a0c-0305e82c3301", [])).to(be(true))
      expect(described_class.dynamic?("a1b2c3d4e5f60718293a4b5c", [])).to(be(true))
      expect(described_class.dynamic?("NEW_RECORD_name", [])).to(be(true))
      expect(described_class.dynamic?("select2-chosen-1", [])).to(be(true))
    end

    it "does not reject a number that is not a known id" do
      expect(described_class.dynamic?("step-2", known)).to(be(false))
      expect(described_class.dynamic?("tab-2024", known)).to(be(false))
    end
  end

  describe ".bootstrap_utility_class?" do
    it "knows the Bootstrap 5.3 utility families" do
      %w[mt-3 px-lg-4 d-flex d-none justify-content-between align-items-center col-md-6 col g-3 fw-bold text-muted
        text-center text-uppercase bg-light position-fixed w-100 rounded-3 shadow-sm fs-5 gap-2 order-2 flex-column
        visually-hidden active show fade collapse btn-sm text-primary border-0 me-auto opacity-50 z-3 top-50 translate-middle].each do |c|
        expect(described_class.bootstrap_utility_class?(c)).to(be(true), c)
      end
    end

    it "keeps semantic classes Studiz uses meaningfully" do
      %w[card-title discount-card js-star btn btn-primary nav-link chosen-select cover-image-upload checkmark
        text-truncate-custom column-header colour-picker generalCont flash-container status-badge textbox].each do |c|
        expect(described_class.bootstrap_utility_class?(c)).to(be(false), c)
      end
    end
  end

  describe ".semantic_classes" do
    it "drops utilities and dynamic classes" do
      expect(described_class.semantic_classes(%w[card mb-3 discount-card active js-star-1695551234567])).to(eq(%w[card discount-card]))
    end
  end

  describe ".href_pattern" do
    it "replaces numeric segments and strips queries" do
      expect(described_class.href_pattern("/udbydere/42/admin/rabatter/7/rediger?x=1")).to(eq("/udbydere/*/admin/rabatter/*/rediger"))
      expect(described_class.href_pattern("/vilkaar")).to(eq("/vilkaar"))
    end
  end
end
