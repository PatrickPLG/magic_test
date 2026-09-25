require "rails_helper"
require "magic_test/wizard"

RSpec.describe(MagicTest::Wizard::Catalogue) do
  subject(:catalogue) { described_class.build(root: Rails.root) }

  it "lists factories with their traits and aliases" do
    discount = catalogue.factory("discount")
    expect(discount.class_name).to(eq("Discount"))
    expect(discount.traits).to(include("active", "archived", "draft", "with_image"))
    org = catalogue.factory("institutions_student_organisation")
    expect(org.class_name).to(eq("Institutions::StudentOrganisation"))
    expect(catalogue.factory("student_organisation")).to(eq(org)) # alias
    expect(catalogue.factories.size).to(be >= 15)
  end

  it "derives the roles from `has_one :user, as: :role` plus custom user resolvers" do
    names = catalogue.roles.map(&:class_name)
    expect(names).to(include("Student", "Provider", "Admin", "Company", "TeamMember", "Institutions::Employee", "Institutions::StudentOrganisation"))
    expect(names).to(include("Institution")) # signs in through its leader employee
    expect(names).not_to(include("Discount", "Lead"))
    expect(catalogue.role("Institutions::StudentOrganisation").factory).to(eq("institutions_student_organisation"))
    expect(catalogue.roles.size).to(be >= 6)
  end

  it "exposes belongs_to reflections with NOT NULL and optional flags" do
    assocs = catalogue.associations_for("discount")
    provider = assocs.find { |a| a.name == "provider" }
    expect(provider.class_name).to(eq("Provider"))
    expect(provider.required?).to(be(true))
    category = catalogue.associations_for("event").find { |a| a.name == "category" }
    expect(category.optional).to(be(true))
    notable = catalogue.associations_for("note").find { |a| a.name == "notable" }
    expect(notable.polymorphic).to(be(true))
    author = catalogue.associations_for("note").find { |a| a.name == "author" }
    expect(author.class_name).to(eq("User"))
    expect(author.required?).to(be(false))
  end

  it "lists named GET routes grouped across locales with their params and namespace" do
    r = catalogue.route("provider_admin_discounts")
    expect(r.params).to(eq(["provider_id"]))
    expect(r.namespace).to(eq("provider"))
    expect(r.localized).to(be(true))
    expect(catalogue.route("backoffice_leads").localized).to(be(false))
    expect(catalogue.route("backoffice_leads").namespace).to(eq("backoffice"))
    expect(catalogue.routes.map(&:name)).not_to(include("provider_admin_discounts_da", "provider_admin_discounts_en"))
    expect(catalogue.routes_for_role("Provider").first.namespace).to(eq("provider"))
    expect(catalogue.routes_for_role("Admin").first.namespace).to(eq("backoffice"))
    expect(catalogue.routes_for_role(nil).first.namespace).to(eq("public"))
  end

  it "finds Flipper flags from Flipper.features and from literals in app code" do
    names = catalogue.flags.map(&:name)
    expect(names).to(include("beta_dashboard", "new_navigation", "ml_recommendations", "live_support"))
    expect(catalogue.flags.find { |f| f.name == "ml_recommendations" }.on_by_default).to(be(true))
    expect(catalogue.flags.find { |f| f.name == "beta_dashboard" }.on_by_default).to(be(false))
  end

  it "lists fixture files, existing system specs and settable attributes with enums" do
    expect(catalogue.fixture_files).to(include("cover.png"))
    expect(catalogue.files).to(all(match(%r{\Aspec/system/.*_spec\.rb\z})))
    attrs = catalogue.attributes_for("lead")
    expect(attrs["priority"][:enum]).to(eq(%w[low normal high]))
    expect(attrs).not_to(have_key("id"))
    expect(catalogue.attribute_settable?("user", "password")).to(be(true))
    expect(catalogue.attribute_settable?("lead", "nope")).to(be(false))
  end
end
