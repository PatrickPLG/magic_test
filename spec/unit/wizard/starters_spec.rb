require "rails_helper"
require "magic_test/wizard"

# 1.2 §5: built-in Studiz starters, adjusted to the learned defaults, with a
# remembered preflight status.
RSpec.describe(MagicTest::Wizard::Starters) do
  let(:catalogue) { MagicTest::Wizard::Catalogue.current }
  let(:status_path) { catalogue.root.join(described_class::STATUS_PATH) }

  before { FileUtils.rm_f(status_path) }

  it "offers one starter per Studiz role, available when its factories and routes exist here" do
    list = described_class.list(catalogue)
    expect(list.map { |s| s["id"] }).to(eq(%w[provider_active_discount institution_leader student_organisation student_verified admin_backoffice guest]))
    expect(list.all? { |s| s["available"] }).to(be(true), list.reject { |s| s["available"] }.map { |s| s["missing"] }.inspect)
    provider = list.first["plan"]
    expect(provider["signed_in"]).to(eq("provider"))
    expect(provider["models"].map { |m| [m["factory"], m["traits"]] }).to(eq([["provider", ["with_cvr"]], ["discount", ["active"]]]))
    expect(provider["start"]).to(include("route" => "provider_admin_discounts", "params" => {"provider_id" => "provider"}))
    expect(provider["starter"]).to(eq("provider_active_discount"))
    expect(MagicTest::Wizard::Plan.from_h(provider).starter).to(eq("provider_active_discount"))
  end

  it "takes the specs' most common trait combination over the seed" do
    institution = described_class.find("institution_leader", catalogue)["plan"]
    expect(institution["models"].first["traits"]).to(eq(%w[with_user with_specialities])) # learned from spec/system/institution/*
  end

  it "remembers the last preflight per starter and flags a failure" do
    expect(described_class.list(catalogue).first["verified_at"]).to(be_nil)
    described_class.record_status(catalogue.root, "provider_active_discount", ok: true)
    described_class.record_status(catalogue.root, "guest", ok: false, message: "root answered 500")
    list = described_class.list(catalogue)
    expect(list.first).to(include("ok" => true))
    expect(Time.iso8601(list.first["verified_at"])).to(be_within(60).of(Time.now))
    expect(list.last).to(include("ok" => false, "message" => "root answered 500"))
    expect(JSON.parse(status_path.read).keys).to(contain_exactly("provider_active_discount", "guest"))
  end

  it "raises for an unknown starter" do
    expect { described_class.find("nope", catalogue) }.to(raise_error(MagicTest::Wizard::Error, /no starter called "nope"/))
  end
end
