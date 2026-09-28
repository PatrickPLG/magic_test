require "rails_helper"
require "magic_test/hints"

# 1.2 §6: every "?" the pages show has a hint, and every hint is complete.
RSpec.describe(MagicTest::Hints) do
  let(:js_sources) do
    Dir[File.expand_path("../../app/assets/javascripts/magic_test/**/*.js", __dir__)].map { |f| File.read(f) }.join("\n")
  end

  it "has a sentence, a when and a 1-3 line example for every hint" do
    expect(described_class.problems).to(be_empty)
    expect(described_class.keys.size).to(be >= 40)
  end

  it "covers every topic the brief lists" do
    wizard = %w[description target_new_file target_append let_bang factory trait count association attribute_override signed_in_role magic_sign_in
      start_page route_params preflight flipper_global flipper_actor travel_to locale viewport sidekiq_inline mail_assertion fixture_file starters templates append_vs_context]
    toolbar = %w[have_content have_no_content have_css have_no_css have_field have_checked_field have_select have_button have_link have_current_path
      modal_closed toast change_count reload_attr confidence why_locator review_comment]
    expect(described_class.payload("wizard").keys).to(include(*wizard))
    expect(described_class.payload("toolbar").keys).to(include(*toolbar))
  end

  it "has a hint for every key the wizard and the toolbar refer to" do
    referenced = js_sources.scan(/hint\(\s*['"]([a-z_]+\.[a-z_]+)['"]/).flatten.uniq
    missing = referenced.reject { |k| described_class.for(k) }
    expect(missing).to(be_empty, "hints referenced in JS but missing from config/hints.yml: #{missing.join(", ")}")
    expect(referenced).not_to(be_empty) # the pages do show hints
  end

  it "looks a key up by section" do
    expect(described_class.for("wizard.trait")["example"]).to(include("create(:provider, :with_cvr)"))
    expect(described_class.for("toolbar.nope")).to(be_nil)
  end
end
