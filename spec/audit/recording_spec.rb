require "rails_helper"

# Phase 0 audit, browser side: record -> generate, driven with CDP-trusted
# input. Example names carry the item number from the task's section 1 list.
RSpec.describe("Audit: recording in the browser", :recorder, type: :system) do
  let!(:provider) { create(:provider) }
  let!(:student) { create(:student, automatic_verified: true).tap { |s| s.user.update!(onboarded: true) } }
  let!(:institution) { create(:institution, :with_user, allow_events: true) }
  let!(:categories) { %w[Fest Foredrag Sport Kultur Musik].map { |n| create(:category, name: n) } }
  let!(:discount) { create(:discount, provider: provider, name_da: "Kaffe 20%", status: "active") }
  let!(:invoice) { create(:invoice, provider: provider) }
  let!(:leads) { 3.times.map { |i| create(:lead, name: "Lead #{i + 1}") } }

  def joined(lines)
    lines.join("\n")
  end

  describe "audit #1: within blocks" do
    it "scopes an icon-only row button to its row instead of a global ambiguous find" do
      sign_in_as_provider(provider)
      visit backoffice_leads_path
      lines = record { |h| h.click("#lead_#{leads[1].id} .js-star") }
      expect(lines).not_to(be_empty)
      expect(joined(lines)).to(match(/within\(/))
    end
  end

  describe "audit #2: highlight-to-assert" do
    it "emits have_content with every quote escaped" do
      visit terms_path
      lines = record do |h|
        h.select_text("p")
        recorder.assert_selection(h)
      end
      expect(joined(lines)).to(include("have_content"))
      expect(joined(lines)).to(include("misbrug"))
      expect(valid_ruby?(lines)).to(be(true))
    end
  end

  describe "audit #4: native select" do
    it "records a keyboard-driven change of a native <select>" do
      sign_in_as_student(student)
      visit edit_profile_path
      lines = record { |h| h.native_select("Land", "Sverige") }
      expect(joined(lines)).to(match(/select\(/))
      expect(joined(lines)).to(include("Sverige"))
    end
  end

  describe "audit #5: label clicks" do
    before { sign_in_as_student(student) }

    it "records check/uncheck for a visually hidden checkbox behind a .checkmark label" do
      visit edit_profile_path
      lines = record { |h| h.click("label.checkmark-container", text: "nyhedsbrev") }
      expect(joined(lines)).to(match(/\bcheck\(/))
      expect(joined(lines)).not_to(include("choose"))
    end

    it "records check('Betalt') for a plain label[for] of a checkbox" do
      visit invoice_path(invoice)
      lines = record { |h| h.click("label", text: "Betalt") }
      expect(joined(lines)).to(match(/\bcheck\(/))
      expect(joined(lines)).not_to(include("choose"))
    end

    it "records choose for a radio behind a .checkmark label" do
      visit edit_profile_path
      lines = record { |h| h.click("label.checkmark-container", text: "Kvinde") }
      expect(joined(lines)).to(match(/\bchoose\(/))
    end

    it "records nothing for a label click on a text field" do
      visit edit_profile_path
      lines = record { |h| h.click("label[for='student_first_name']") }
      expect(lines).to(be_empty)
    end
  end

  describe "audit #6: typing is recorded from the final value" do
    before { sign_in_as_student(student) }

    it "reflects a trailing Backspace" do
      visit edit_profile_path
      lines = record { |h| h.fill("#student_first_name", "Mettes").press(:backspace) }
      expect(joined(lines)).to(include("fill_in"))
      expect(joined(lines)).to(include("'Mette'"))
      expect(joined(lines)).not_to(include("Mettes"))
    end

    it "records a paste" do
      visit edit_profile_path
      lines = record { |h| h.click("#student_last_name").select_all.paste("Nielsen") }
      expect(joined(lines)).to(include("Nielsen"))
    end

    it "does not put a carriage return into the value when Enter is pressed" do
      visit user_messages_path
      lines = record { |h| h.click("#user_message_body").type("Hej").press(:enter) }
      expect(joined(lines)).to(include("Hej"))
      expect(joined(lines)).not_to(include("\\r"))
      expect(joined(lines)).not_to(include("\r"))
    end

    it "keeps newlines in a textarea as valid Ruby" do
      visit edit_profile_path
      lines = record { |h| h.click("#student_bio").type("Linje 1").press(:enter).type("Linje 2") }
      expect(valid_ruby?(lines)).to(be(true))
      expect(joined(lines)).to(match(/Linje 1(\\n|\n)Linje 2/))
    end

    it "preserves leading and trailing whitespace" do
      visit edit_profile_path
      lines = record { |h| h.fill("#student_first_name", "  hej ") }
      expect(joined(lines)).to(include("'  hej '"))
    end

    it "records the right value after editing in the middle of the text" do
      visit edit_profile_path
      lines = record { |h| h.fill("#student_first_name", "Hej verden").press(:home).type("Ø: ") }
      expect(joined(lines)).to(include("Ø: Hej verden"))
    end
  end

  describe "audit #7: quoting of typed values" do
    it "produces valid Ruby for an apostrophe typed into a field" do
      sign_in_as_student(student)
      visit edit_profile_path
      lines = record { |h| h.fill("#student_first_name", "it's") }
      expect(joined(lines)).to(include("fill_in"))
      expect(valid_ruby?(lines)).to(be(true))
    end
  end

  describe "audit #8: Trix" do
    it "records text typed into a trix-editor" do
      sign_in_as_institution(institution)
      visit new_institution_event_path(institution)
      lines = record { |h| h.click("trix-editor").type("Kom til fest") }
      expect(joined(lines)).to(include("Kom til fest"))
    end
  end

  describe "audit #9: file inputs" do
    it "records attach_file for the visually hidden cover image input" do
      sign_in_as_provider(provider)
      visit edit_provider_admin_discount_path(provider, discount)
      lines = record { |h| h.attach("#cover_image_discount_#{discount.id}_cover_image", Rails.root.join("../fixtures/files/cover.png")) }
      expect(joined(lines)).to(match(/attach_file|magic_attach_image/))
    end
  end

  describe "audit #10: Chosen search then select" do
    it "emits one step for the pick, never a second toggling open click" do
      sign_in_as_institution(institution)
      visit new_institution_event_path(institution)
      lines = record do |h|
        h.click("#events_event_category_id_chosen")
        h.type("Fe")
        h.click("#events_event_category_id_chosen .chosen-results li.active-result", text: "Fest")
      end
      chosen_lines = lines.select { |l| l.include?("events_event_category_id") || l.include?("Kategori") }
      expect(chosen_lines.size).to(eq(1))
      expect(chosen_lines.first).to(include("Fest"))
    end
  end

  describe "audit #11: record-dependent ids" do
    it "never emits an id containing the record id" do
      sign_in_as_provider(provider)
      visit invoice_path(invoice)
      lines = record { |h| h.click("#invoice_#{invoice.id}_paid") }
      expect(lines).not_to(be_empty)
      expect(joined(lines)).not_to(match(/invoice_\d+/))
    end

    it "never emits trix_input_N or nested-attribute timestamps" do
      sign_in_as_institution(institution)
      visit new_institution_event_path(institution)
      lines = record do |h|
        h.click("trix-editor").type("Tekst")
        h.click_on("Billetter")
        h.click_on("Tilføj billettype")
        h.click_on("Tilføj billettype")
        h.click("#ticket-types .ticket-type-fields:last-child input[name*='[name]']").type("VIP")
      end
      expect(joined(lines)).not_to(match(/trix_input_\d+/))
      expect(joined(lines)).not_to(match(/\d{10,}/))
      expect(joined(lines)).not_to(match(/_attributes_\d+_/))
    end
  end

  describe "audit #12: click_on ambiguity" do
    it "does not emit a bare click_on for a label that matches several elements" do
      sign_in_as_provider(provider)
      visit backoffice_leads_path
      expect(page.all(:link_or_button, "Rediger").size).to(be > 1)
      lines = record { |h| h.click("#lead_#{leads[1].id} a", text: "Rediger") }
      expect(lines).not_to(be_empty)
      expect(lines).not_to(include(match(/\Aclick_on\(?\s*['"]Rediger['"]\)?\z/)))
    end
  end

  describe "audit #13: stopPropagation" do
    it "still records a click whose app handler stops propagation" do
      sign_in_as_student(student)
      visit root_path(hide_onboarding: 1)
      page.execute_script("document.querySelectorAll('.modal.show').forEach(m => bootstrap.Modal.getInstance(m).hide())")
      lines = record { |h| h.click("#discount-card-#{discount.id} .card-title") }
      expect(lines).not_to(be_empty)
    end
  end

  describe "audit #14: fast successive clicks" do
    it "records two quick clicks on different elements" do
      sign_in_as_institution(institution)
      visit new_institution_event_path(institution)
      lines = record { |h| h.click_on("Arrangør"); h.click_on("Billetter") }
      expect(joined(lines)).to(include("Arrangør"))
      expect(joined(lines)).to(include("Billetter"))
    end
  end

  describe "audit #15: submits and dialogs" do
    it "records Enter submitting a form" do
      sign_in_as_student(student)
      visit user_messages_path
      lines = record { |h| h.click("#user_message_body").type("Hej").press(:enter) }
      expect(page).to(have_content("Besked sendt"))
      expect(joined(lines)).to(match(/send_keys\(:enter\)/))
    end

    it "wraps a rails-ujs data-confirm click in accept_confirm" do
      sign_in_as_provider(provider)
      visit provider_admin_discounts_path(provider)
      lines = record do |h|
        h.click_on("Slet")
        recorder.answer_dialog(h, :accept)
      end
      expect(page).to(have_content("Rabat slettet"))
      expect(joined(lines)).to(include("accept_confirm"))
    end

    it "wraps a native alert() from a js.erb response in accept_alert" do
      sign_in_as_provider(provider)
      visit provider_admin_discounts_path(provider)
      lines = record do |h|
        h.click_on("Send påmindelse")
        recorder.answer_dialog(h, :accept)
      end
      expect(joined(lines)).to(include("accept_alert"))
    end
  end

  describe "audit #16: the recorder's own prompts" do
    it "does not open a native window.confirm the human never sees" do
      visit terms_path
      dialogs = 0
      page.driver.browser.page.on("Page.javascriptDialogOpening") { |_params| dialogs += 1 }
      record do |h|
        h.select_text("p")
        recorder.assert_selection(h)
      end
      expect(dialogs).to(eq(0))
    end
  end

  describe "audit #17: navigation" do
    it "records visit for a page load that was not caused by a click" do
      visit root_path
      lines = record { |h| h.visit(terms_path) }
      expect(joined(lines)).to(match(/visit\(/))
    end
  end

  describe "audit #18/#19: mouseover side effects" do
    it "logs nothing and observes nothing on plain mouse movement" do
      visit terms_path
      logs = []
      page.driver.browser.page.on("Runtime.consoleAPICalled") { |params| logs << params.dig("args", 0, "value").to_s }
      lines = record { |h| h.hover("h1"); h.hover("p") }
      expect(logs).to(be_empty)
      expect(joined(lines)).not_to(include(".hover"))
    end
  end

  describe "audit #20: global namespace" do
    it "defines no bare globals" do
      visit terms_path
      globals = page.evaluate_script("['ready','isUnique','clickFunction','getPathTo','codes','mutationStart','mutationEnd','initializeMutationObserver','finderForElement','visibleFilter'].filter(n => typeof window[n] !== 'undefined')")
      expect(globals).to(eq([]))
    end

    it "survives being rendered twice in one document (mail layouts)" do
      expect { visit double_render_path }.not_to(raise_error)
    end
  end

  describe "audit #21: right-click" do
    it "does not permanently disable the context menu" do
      visit terms_path
      record { |h| h.right_click("h1"); h.right_click("h1") }
      prevented = page.evaluate_script("!document.body.dispatchEvent(new MouseEvent('contextmenu', {bubbles: true, cancelable: true}))")
      expect(prevented).to(be(false))
    end
  end

  describe "audit #29 (found): session start before the first page load" do
    it "does not crash when the recorder starts on about:blank" do
      expect { recorder.start }.not_to(raise_error)
    end
  end

  describe "audit #28: console noise" do
    it "logs nothing to the console on page load" do
      logs = []
      page.driver.browser.page.on("Runtime.consoleAPICalled") { |params| logs << params.dig("args", 0, "value").to_s }
      visit terms_path
      sleep 0.3
      expect(logs.select { |l| l =~ /magic/i }).to(be_empty)
    end
  end
end
