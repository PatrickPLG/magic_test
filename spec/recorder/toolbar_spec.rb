require "rails_helper"

# The toolbar lives in a Shadow DOM host (`[data-magic-test=toolbar]`). These
# examples read its text the way a person sees it, after real clicks.
RSpec.describe("Toolbar", :recorder, type: :system) do
  let!(:provider) { create(:provider, :with_cvr) }
  let!(:discount) { create(:discount, provider: provider, name_da: "Kaffe 20%", status: "active") }

  def toolbar_text
    page.evaluate_script("(function () { var h = document.querySelector('[data-magic-test=toolbar]'); return h && h.shadowRoot ? h.shadowRoot.textContent : null; })()")
  end

  def wait_for_toolbar(timeout: 5)
    deadline = Time.now + timeout
    loop do
      text = toolbar_text
      return text if text && yield(text)
      raise "toolbar never showed the expected text; last text: #{text.inspect}" if Time.now > deadline
      sleep 0.1
    end
  end

  before { sign_in_as_provider(provider) }

  it "mounts in the page and lists each recorded step as the Ruby line it will write" do
    visit provider_admin_discounts_path(provider)
    recorder.start
    wait_for_toolbar { |t| t.include?("Steps (0 pending") }
    human.click_on("Rediger")
    wait_for_toolbar { |t| t.include?("click_on(I18n.t('discounts.index.edit'))") }
    text = wait_for_toolbar { |t| t.include?("1 pending") }
    expect(text).to(include("Steps (1 pending, 0 saved)"))
  end

  it "shows the flash assertion suggestion after a save and adds it as a step when accepted" do
    visit edit_provider_admin_discount_path(provider, discount)
    recorder.start
    human.click_on("Gem")
    text = wait_for_toolbar { |t| t.include?("have_content(I18n.t('discounts.update.success'))") }
    expect(text).to(include("Suggested assertions"))
    suggestion = recorder.state["suggestions"].find { |s| s["code"].include?("discounts.update.success") }
    recorder.session.enqueue_command("accept_suggestion", "suggestion_id" => suggestion["id"])
    wait_for_toolbar { |t| t.include?("2 pending") }
    expect(recorder.lines.join("\n")).to(include("expect(page).to(have_content(I18n.t('discounts.update.success')))"))
  end

  it "is not mounted inside iframes" do
    visit preview_path
    recorder.start
    wait_for_toolbar { |t| t.include?("Steps") }
    within_frame("preview") do
      expect(page.evaluate_script("!!document.querySelector('[data-magic-test=toolbar]')")).to(be(false))
    end
  end

  # 1.2 §6: "?" hints in the toolbar, and "Why this locator?" on a step's badge.
  describe "hints" do
    def shadow_click(css)
      page.execute_script("(function () { var h = document.querySelector('[data-magic-test=toolbar]'); var el = h.shadowRoot.querySelector(#{css.inspect}); el.dispatchEvent(new MouseEvent('click', {bubbles: true})); })()")
    end

    def shadow_focus(css)
      page.execute_script("(function () { var h = document.querySelector('[data-magic-test=toolbar]'); h.shadowRoot.querySelector(#{css.inspect}).dispatchEvent(new FocusEvent('focus')); })()")
    end

    it "explains the assertion type and the selection assertions from config/hints.yml, on focus, closed by Esc" do
      visit provider_admin_discounts_path(provider)
      recorder.start
      wait_for_toolbar { |t| t.include?("Steps (0 pending") }
      shadow_focus("button[data-hint-for=assertion-type]")
      text = wait_for_toolbar { |t| t.include?("have_css checks that an element matches") }
      expect(text).to(include("When: For rows, cards and badges", "expect(page).to(have_css('.deal', count: 2))"))
      page.execute_script("(function () { var h = document.querySelector('[data-magic-test=toolbar]'); h.shadowRoot.querySelector('select.alt').value = 'field'; h.shadowRoot.querySelector('select.alt').dispatchEvent(new Event('change')); })()")
      shadow_focus("button[data-hint-for=assertion-type]")
      wait_for_toolbar { |t| t.include?("have_field checks a form field") }
      shadow_focus("button[data-hint='toolbar.have_no_content']")
      wait_for_toolbar { |t| t.include?("never passes early like not_to have_content can") }
      page.execute_script("document.dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape', bubbles: true}))")
      wait_for_toolbar { |t| !t.include?("never passes early") }
    end

    it "opens 'Why this locator?' from a step's badge with the chosen code and the alternatives" do
      visit provider_admin_discounts_path(provider)
      recorder.start
      wait_for_toolbar { |t| t.include?("Steps (0 pending") }
      human.click_on("Rediger")
      wait_for_toolbar { |t| t.include?("click_on(I18n.t('discounts.index.edit'))") }
      shadow_click("button.badge")
      text = wait_for_toolbar { |t| t.include?("Why this locator?") }
      expect(text).to(include("A verified unique semantic locator", "ranks every candidate that matches exactly one element"))
      expect(text).to(match(/a\.btn|href|CSS ranks below labels/))
    end

    it "gives every suggested assertion a hint of its own" do
      visit edit_provider_admin_discount_path(provider, discount)
      recorder.start
      wait_for_toolbar { |t| t.include?("Steps (0 pending") }
      human.click("#discount_name_da").select_all.type("Kaffe 25%")
      human.click_on("Gem")
      wait_for_toolbar { |t| t.include?("Suggested assertions") && t.include?("have_current_path") }
      shadow_focus(".sugg button[data-hint='toolbar.have_current_path']")
      wait_for_toolbar { |t| t.include?("have_current_path waits for the URL, so it survives redirects") }
      shadow_focus(".sugg button[data-hint='toolbar.have_content']")
      wait_for_toolbar { |t| t.include?("have_content waits for the text to appear anywhere on the page") }
    end
  end
end
