require "rails_helper"

RSpec.describe(MagicTest::Codegen::Emitter) do
  Step = MagicTest::Codegen::Step
  Scope = MagicTest::Codegen::Scope
  Wrapper = MagicTest::Codegen::Wrapper

  def within(css, text = nil)
    Scope.new(kind: :within, open: text ? "within('#{css}', text: '#{text}') do" : "within('#{css}') do", key: "within:#{css}:#{text}")
  end

  it "renders plain steps with an indentation prefix" do
    lines = described_class.new([Step.new(kind: :click, lines: ["click_on('A')"]), Step.new(kind: :fill, lines: ["fill_in('B', with: 'c')"])], indent: "    ").render
    expect(lines).to(eq(["    click_on('A')", "    fill_in('B', with: 'c')"]))
  end

  it "merges consecutive steps that share a scope into one block and nests scopes" do
    modal = within("#ajax-modal")
    row = within("tr", "Kaffe 20%")
    steps = [
      Step.new(kind: :click, lines: ["click_on('Tilføj medlem')"]),
      Step.new(kind: :fill, lines: ["fill_in('Navn', with: 'Ida')"], scopes: [modal]),
      Step.new(kind: :fill, lines: ["fill_in('E-mail', with: 'ida@x.dk')"], scopes: [modal]),
      Step.new(kind: :click, lines: ["click_on('Rediger')"], scopes: [modal, row]),
      Step.new(kind: :click, lines: ["click_on('Tilføj')"], scopes: [modal]),
      Step.new(kind: :assert, lines: ["expect(page).to(have_content('Medlem tilføjet'))"])
    ]
    expect(described_class.new(steps).render).to(eq([
      "click_on('Tilføj medlem')",
      "within('#ajax-modal') do",
      "  fill_in('Navn', with: 'Ida')",
      "  fill_in('E-mail', with: 'ida@x.dk')",
      "  within('tr', text: 'Kaffe 20%') do",
      "    click_on('Rediger')",
      "  end",
      "  click_on('Tilføj')",
      "end",
      "expect(page).to(have_content('Medlem tilføjet'))"
    ]))
  end

  it "does not merge across a different outer scope" do
    a = Scope.new(kind: :window, open: "within_window(new_window) do", key: "window:w2")
    steps = [
      Step.new(kind: :click, lines: ["click_on('X')"], scopes: [within("#m")]),
      Step.new(kind: :click, lines: ["click_on('Y')"], scopes: [a, within("#m")])
    ]
    expect(described_class.new(steps).render).to(eq([
      "within('#m') do", "  click_on('X')", "end",
      "within_window(new_window) do", "  within('#m') do", "    click_on('Y')", "  end", "end"
    ]))
  end

  it "wraps a step in its dialog wrapper and puts review comments above" do
    step = Step.new(kind: :click, lines: ["click_on('Slet')"], wrapper: Wrapper.new(open: "accept_confirm('Er du sikker?') do"), review: "check this", scopes: [within("#list")])
    expect(described_class.new([step]).render).to(eq([
      "within('#list') do",
      "  # magic_test: REVIEW check this",
      "  accept_confirm('Er du sikker?') do",
      "    click_on('Slet')",
      "  end",
      "end"
    ]))
  end
end
