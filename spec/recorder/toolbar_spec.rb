require "rails_helper"

# The toolbar lives in a Shadow DOM host (`[data-magic-test=toolbar]`). These
# examples read its text the way a person sees it, after real clicks.
RSpec.describe("Toolbar", :recorder, type: :system) do
  let!(:provider) { create(:provider) }
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
end
