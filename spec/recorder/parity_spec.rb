require "rails_helper"

# Proves the browser-side uniqueness check equals Capybara's own matching:
# for every (selector kind, locator) pair the JS exact/partial counts must
# equal `page.all(kind, locator, exact: true/false).size`, on several fixture
# pages, with the same visibility/disabled filters.
RSpec.describe("Capybara matching parity", :recorder, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:institution) { create(:institution, :with_user, allow_events: true) }
  let!(:student) { create(:student, automatic_verified: true).tap { |s| s.user.update!(onboarded: true) } }
  let!(:categories) { %w[Fest Foredrag Sport Kultur Musik].map { |n| create(:category, name: n) } }
  let!(:discounts) { [create(:discount, provider: provider, name_da: "Kaffe 20%"), create(:discount, provider: provider, name_da: "Te 10%")] }
  let!(:leads) { 3.times.map { |i| create(:lead, name: "Lead #{i + 1}") } }

  let(:locators) do
    {
      link_or_button: ["Rabatter", "Gem", "Gem arrangement", "Rediger", "Slet", "Arrangementer", "Send", "Deaktiveret", "Skjult link", "Læs Studiz' vilkår", "Se \"Fest\" arrangementer", "Beskeder", "arrangement", "Indstillinger", "Opret arrangement", "Arrangør", "Tilføj billettype", "Send påmindelse", "Se faktura", "x"],
      link: ["Rabatter", "Rediger", "Skjult link", "Beskeder", "Arrangementer", "Se faktura"],
      button: ["Gem", "Send", "Deaktiveret", "Gem arrangement", "Send påmindelse", "Arrangør"],
      fillable_field: ["Fornavn", "* Fornavn", "profile_first_name", "profile[first_name]", "Dit fornavn", "Efternavn", "Om mig", "profile[locked]", "Navn", "* Navn", "Kontonummer", "events_event_name", "Starttidspunkt", "Billettype"],
      select: ["Land", "Kategori", "profile_country", "Status", "Kategorier"],
      checkbox: ["Nyhedsbrev", "Jeg accepterer Studiz' vilkår", "profile[terms]", "Offentliggjort"],
      radio_button: ["Kvinde", "profile_gender_female", "Mand"],
      file_field: ["profile[avatar]", "discount[cover_image]", "Coverbillede"]
    }
  end

  def js_count(kind, locator, visible_all: false)
    page.evaluate_script(<<~JS, kind.to_s, locator, visible_all)
      (function (kind, locator, visibleAll) {
        var MT = window.MagicTest.__internals;
        var c = MT.capybara.count(kind, locator, document, null, { visibleAll: visibleAll });
        return [c.exact, c.partial];
      })(arguments[0], arguments[1], arguments[2])
    JS
  end

  def ruby_count(kind, locator, visible_all: false)
    opts = visible_all ? {visible: :all} : {}
    [page.all(kind, locator, exact: true, wait: 0, **opts).size, page.all(kind, locator, exact: false, wait: 0, **opts).size]
  end

  def check_page
    mismatches = []
    locators.each do |kind, locs|
      locs.each do |locator|
        [false, true].each do |visible_all|
          next if visible_all && !%i[checkbox radio_button select file_field fillable_field].include?(kind)
          js = js_count(kind, locator, visible_all: visible_all)
          rb = ruby_count(kind, locator, visible_all: visible_all)
          mismatches << "#{kind} #{locator.inspect}#{" (visible: :all)" if visible_all}: js=#{js.inspect} ruby=#{rb.inspect}" unless js == rb
        end
      end
    end
    expect(mismatches).to(be_empty, lambda { "JS and Capybara disagree:\n  " + mismatches.join("\n  ") })
  end

  it "agrees on the JS playground page" do
    sign_in_as_provider(provider)
    visit "/js-test-page?discount_id=#{discounts.first.id}"
    recorder.start
    check_page
  end

  it "agrees on the event form (simple_form, Chosen, flatpickr, Trix, tabs)" do
    sign_in_as_institution(institution)
    visit new_institution_event_path(institution)
    recorder.start
    human.click_on("Billetter").click_on("Tilføj billettype")
    check_page
  end

  it "agrees on the provider discounts page and the edit form" do
    sign_in_as_provider(provider)
    visit provider_admin_discounts_path(provider)
    recorder.start
    check_page
    visit edit_provider_admin_discount_path(provider, discounts.first)
    recorder.sync_browser
    check_page
  end

  it "agrees on the backoffice leads table and the student profile" do
    sign_in_as_student(student)
    visit edit_profile_path
    recorder.start
    check_page
    visit backoffice_leads_path
    recorder.sync_browser
    check_page
  end

  it "agrees inside an open modal" do
    org = create(:student_organisation)
    sign_in_as_student_organisation(org)
    visit student_organisation_student_organisation_memberships_path
    recorder.start
    human.click_on("Tilføj medlem")
    expect(page).to(have_css("#ajax-modal.show #membership-form"))
    check_page
    within("#ajax-modal") do
      %w[Navn E-mail Medlemstype Tilføj Annuller].each do |loc|
        kind = if %w[Tilføj Annuller].include?(loc)
          :link_or_button
        elsif loc == "Medlemstype"
          :select
        else
          :fillable_field
        end
        js = page.evaluate_script("(function(){var MT=window.MagicTest.__internals;var c=MT.capybara.count(#{kind.to_s.inspect}, #{loc.inspect}, document.querySelector('#ajax-modal'));return [c.exact,c.partial];})()")
        expect(js).to(eq([page.all(kind, loc, exact: true, wait: 0).size, page.all(kind, loc, exact: false, wait: 0).size]), "#{kind} #{loc} in modal")
      end
    end
  end
end
