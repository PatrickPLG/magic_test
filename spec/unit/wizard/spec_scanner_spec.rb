require "rails_helper"
require "magic_test/wizard"

# 1.2 §4: the wizard learns the host's conventions from spec/**/*.rb with the
# same AST approach as SpecFile, caches per file mtime, and ranks from that.
RSpec.describe(MagicTest::Wizard::SpecScanner) do
  let(:root) { Rails.root } # the fixture app: spec/fixture_app/spec/system/** holds Studiz-style specs

  it "counts factory use, trait combinations and kwargs per factory" do
    learned = described_class.scan(root, cache: false)
    expect(learned.files).to(be >= 9)
    expect(learned.usage("provider")).to(be >= 3)
    traits, files = learned.default_traits("provider")
    expect(traits).to(eq(["with_cvr"]))
    expect(files).to(be >= 2)
    expect(learned.trait_combinations("provider").map(&:first)).to(include(["with_cvr"], %w[with_cvr with_english_company_description]))
    expect(learned.default_traits("institution").first).to(eq(%w[with_user with_specialities])) # as written in the specs
    expect(learned.common_kwargs("discount")).to(include("provider", "name_da"))
    expect(learned.factories.dig("event", "methods")).to(include("create_list" => 1))
    expect(learned.default_traits("no_such_factory")).to(eq([[], 0]))
  end

  it "learns which factory and traits each sign-in helper takes, and magic_sign_in/sign_in through the let" do
    learned = described_class.scan(root, cache: false)
    expect(learned.sign_in_for("provider")).to(include("factory" => "provider", "traits" => ["with_cvr"]))
    expect(learned.sign_in_for("institution")).to(include("factory" => "institution"))
    expect(learned.sign_in_for("institution")["traits"]).to(contain_exactly("with_user", "with_specialities"))
    expect(learned.sign_in_for("admin")).to(include("factory" => "admin")) # `sign_in admin.user` resolves through the let
    expect(learned.sign_in_for("nobody")).to(be_nil)
  end

  it "learns the start pages each role visits, guests included" do
    learned = described_class.scan(root, cache: false)
    expect(learned.route_visits("provider")["provider_admin_discounts"]).to(be >= 3)
    expect(learned.route_visits("institution")).to(include("institution_events", "new_institution_event", "institution_students"))
    expect(learned.route_visits("guest")).to(include("terms"))
    expect(learned.route_visits("student")).to(eq({"edit_profile" => 1}))
  end

  describe "cache" do
    let(:cache) { root.join(described_class::CACHE_PATH) }

    before { FileUtils.rm_f(cache) }

    it "writes one entry per file keyed by mtime and reuses unchanged entries" do
      described_class.scan(root)
      data = JSON.parse(cache.read)
      expect(data["version"]).to(eq(described_class::CACHE_VERSION))
      entry = data["files"]["spec/system/provider/provider_discounts_page_spec.rb"]
      expect(entry["mtime"]).to(eq(File.mtime(root.join("spec/system/provider/provider_discounts_page_spec.rb")).to_f))
      expect(entry["data"]["factories"]["provider"]["combos"]).to(eq({"with_cvr" => 1}))

      # A stale entry is re-parsed, an unchanged one is not.
      data["files"]["spec/system/provider/provider_discounts_page_spec.rb"]["data"]["factories"] = {"bogus" => {"count" => 99, "combos" => {}, "kwargs" => {}, "methods" => {}}}
      data["files"]["spec/system/public/terms_spec.rb"]["mtime"] = 1.0
      data["files"]["spec/system/public/terms_spec.rb"]["data"]["routes"] = {"guest" => {"stale_route" => 5}}
      cache.write(JSON.generate(data))
      learned = described_class.scan(root)
      expect(learned.usage("bogus")).to(eq(99)) # unchanged mtime: the cached entry is trusted
      expect(learned.route_visits("guest")).not_to(include("stale_route")) # changed mtime: parsed again
    end

    it "ignores a cache of another version or with broken JSON" do
      cache.dirname.mkpath
      cache.write("{not json")
      expect(described_class.scan(root).usage("provider")).to(be >= 3)
      cache.write(JSON.generate({"version" => 0, "files" => {"x" => {}}}))
      expect(described_class.scan(root).usage("provider")).to(be >= 3)
    end
  end
end
