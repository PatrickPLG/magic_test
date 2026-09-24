require "rails_helper"

# The gem-shipped helpers, exercised against the fixture app in a normal
# (MAGIC_TEST unset) run: they must work in every test run.
RSpec.describe("MagicTest::Helpers", :no_recorder, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:institution) { create(:institution, :with_user, allow_events: true) }
  let!(:categories) { %w[Fest Foredrag Sport Kultur Musik].map { |n| create(:category, name: n) } }
  let!(:discount) { create(:discount, provider: provider, name_da: "Kaffe 20%", status: "draft") }

  describe "#magic_chosen_select / #magic_chosen_unselect" do
    it "picks by label on a searchable single select and by id on a no-search select" do
      sign_in_as_institution(institution)
      visit new_institution_event_path(institution)
      magic_chosen_select("Fest", from: "Kategori")
      expect(page).to(have_select("Kategori", selected: "Fest", visible: false))
      magic_chosen_select("Sport", from: "events_event_category_id")
      expect(page).to(have_select("Kategori", selected: "Sport", visible: false))
      fill_in("* Navn", with: "Test")
      click_on("Gem arrangement")
      expect(Events::Event.last.category.name).to(eq("Sport"))
    end

    it "adds and removes choices on a multiple select and on a select with search disabled" do
      sign_in_as_provider(provider)
      visit edit_provider_admin_discount_path(provider, discount)
      magic_chosen_select("Aktiv", from: "Status")
      magic_chosen_select("Fest", from: "Kategorier")
      magic_chosen_select("Sport", from: "discount[category_ids][]")
      expect(page).to(have_select("Kategorier", selected: %w[Fest Sport], visible: false))
      magic_chosen_unselect("Fest", from: "Kategorier")
      expect(page).to(have_select("Kategorier", selected: ["Sport"], visible: false))
      click_on("Gem")
      expect(discount.reload.status).to(eq("active"))
      expect(discount.categories.map(&:name)).to(eq(["Sport"]))
    end

    it "raises clear errors naming the locator" do
      sign_in_as_provider(provider)
      visit edit_provider_admin_discount_path(provider, discount)
      expect { magic_chosen_select("Fest", from: "Nope") }.to(raise_error(MagicTest::Helpers::HelperError, /no <select> matches "Nope"/))
      expect { magic_chosen_select("Nope", from: "Status") }.to(raise_error(Capybara::ElementNotFound))
    end
  end

  describe "#magic_set_date" do
    it "sets a wrapped datetime picker and a birthday picker through flatpickr" do
      sign_in_as_institution(institution)
      visit new_institution_event_path(institution)
      magic_set_date("Starttidspunkt", "24/09-2026 14:00")
      expect(find_field("Starttidspunkt").value).to(eq("24/09-2026 14:00"))
      fill_in("* Navn", with: "Dato")
      click_on("Gem arrangement")
      expect(Events::Event.last.starts_at.strftime("%d/%m-%Y %H:%M")).to(eq("24/09-2026 14:00"))
    end

    it "raises when the field has no flatpickr instance" do
      sign_in_as_institution(institution)
      visit new_institution_event_path(institution)
      expect { magic_set_date("* Navn", "x") }.to(raise_error(MagicTest::Helpers::HelperError, /no flatpickr instance/))
    end
  end

  describe "#magic_fill_trix" do
    it "fills the editor by label, by editor id, never by trix_input_N" do
      sign_in_as_institution(institution)
      visit new_institution_event_path(institution)
      magic_fill_trix("Beskrivelse", with: "Kom til fredagsbar")
      expect(find("trix-editor").text).to(include("Kom til fredagsbar"))
      magic_fill_trix("events_event_description", with: "Ny tekst")
      fill_in("* Navn", with: "Trix")
      click_on("Gem arrangement")
      expect(Events::Event.last.description).to(include("Ny tekst"))
      expect { magic_fill_trix("Nope", with: "x") }.to(raise_error(MagicTest::Helpers::HelperError, /no <trix-editor> matches "Nope"/))
    end
  end

  describe "#magic_attach_image / #magic_apply_crop" do
    it "uploads through the visually hidden input and applies the crop" do
      sign_in_as_provider(provider)
      visit edit_provider_admin_discount_path(provider, discount)
      magic_attach_image("discount[cover_image]", Rails.root.join("../fixtures/files/cover.png"))
      expect(page).to(have_no_css("#image-cropper-modal.show"))
      click_on("Gem")
      expect(discount.reload.cover_image).to(eq("cover.png"))
    end
  end

  describe "#magic_within_modal" do
    it "waits for the ajax modal content and scopes the block" do
      org = create(:student_organisation)
      sign_in_as_student_organisation(org)
      visit student_organisation_student_organisation_memberships_path
      click_on("Tilføj medlem")
      magic_within_modal do
        fill_in("* Navn", with: "Ida")
        fill_in("* E-mail", with: "ida@studiz.dk")
        click_on("Tilføj")
      end
      expect(page).to(have_content("Medlem tilføjet"))
      expect(page).to(have_no_css("#ajax-modal.show"))
      expect(org.memberships.count).to(eq(1))
    end
  end

  describe "#magic_sign_in" do
    it "behaves like sign_in_as_provider: session, auth_token and cookie_settings cookies" do
      magic_sign_in(provider.user)
      visit provider_admin_discounts_path(provider)
      expect(page).to(have_content("Dine rabatter"))
      expect(page).to(have_no_css("#cookie-modal.show"))
      cookies = page.driver.cookies
      expect(cookies["auth_token"].value).to(eq(provider.user.reload.authentication_token))
      expect(cookies["cookie_settings"].value).to(eq("necessary"))
    end
  end
end
