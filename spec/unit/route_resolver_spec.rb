require "rails_helper"

RSpec.describe(MagicTest::RouteResolver) do
  let(:resolver) { described_class.new }
  let!(:institution) { create(:institution) }
  let!(:provider) { create(:provider) }
  let!(:discount) { create(:discount, provider: provider) }

  it "prefers the locale-agnostic helper for Danish (default locale) paths" do
    result = resolver.resolve("/institutioner/#{institution.id}/arrangementer", memoized: {institution: institution})
    expect(result.code).to(eq("institution_events_path(institution)"))
    expect(result.review?).to(be(false))
  end

  it "uses the explicit _en helper for English paths" do
    result = resolver.resolve("/en/institutions/#{institution.id}/events", memoized: {institution: institution})
    expect(result.code).to(eq("institution_events_en_path(institution)"))
  end

  it "maps nested params to let variables" do
    result = resolver.resolve("/udbydere/#{provider.id}/admin/rabatter/#{discount.id}/rediger", memoized: {provider: provider, discount: discount})
    expect(result.code).to(eq("edit_provider_admin_discount_path(provider, discount)"))
  end

  it "never emits a literal id: unknown records become Model.find with a REVIEW" do
    result = resolver.resolve("/udbydere/#{provider.id}/admin/rabatter", memoized: {})
    expect(result.code).to(eq("provider_admin_discounts_path(Provider.find(#{provider.id}))"))
    expect(result.review?).to(be(true))
    expect(result.args.first.review).to(include("no `let` holds the record"))
  end

  it "resolves namespaced controllers' models for :id" do
    other = create(:discount, provider: provider)
    result = resolver.resolve("/udbydere/#{provider.id}/admin/rabatter/#{other.id}/rediger", memoized: {provider: provider})
    expect(result.code).to(eq("edit_provider_admin_discount_path(provider, Discount.find(#{other.id}))"))
  end

  it "handles the unlocalised backoffice namespace, root and query strings" do
    expect(resolver.resolve("/backoffice/leads").code).to(eq("backoffice_leads_path"))
    expect(resolver.resolve("/backoffice/leads?page=2").code).to(eq("backoffice_leads_path(page: '2')"))
    expect(resolver.resolve("/").code).to(eq("root_path"))
    expect(resolver.resolve("/en").code).to(eq("root_en_path"))
  end

  it "reports ambiguity when two lets have the same id" do
    twin = create(:provider)
    allow(twin).to(receive(:id).and_return(institution.id))
    result = resolver.resolve("/institutioner/#{institution.id}/studerende", memoized: {institution: institution, provider: twin})
    expect(result.code).to(eq("institution_students_path(institution)"))
  end

  it "returns a review when nothing matches" do
    result = resolver.resolve("/no/such/path")
    expect(result.code).to(be_nil)
    expect(result.review).to(include("no named route"))
  end
end
