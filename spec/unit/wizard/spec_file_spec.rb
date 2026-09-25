require "rails_helper"
require "magic_test/wizard"

RSpec.describe(MagicTest::Wizard::SpecFile) do
  def fixture(name)
    dir = Rails.root.join("tmp/wizard_spec_fixtures")
    FileUtils.mkdir_p(dir)
    path = dir.join(name)
    FileUtils.cp(File.expand_path("../../fixtures/wizard/#{name}.txt", __dir__), path)
    path.to_s
  end

  it "parses describe/context blocks with lets, before sign-ins, examples and line ranges" do
    file = described_class.parse(fixture("provider_discounts_spec.rb"))
    top = file.blocks.first
    expect(top.kind).to(eq("describe"))
    expect(top.description).to(eq("Provider discounts"))
    expect(top.first_line).to(eq(4))
    expect(top.last_line).to(eq(26))
    expect(top.indent).to(eq(0))
    expect(top.lets.map(&:to_h)).to(eq([
      {name: "provider", bang: false, factory: "provider", traits: ["with_cvr"], kwargs: {}, line: 5},
      {name: "discount", bang: true, factory: "discount", traits: ["active"], kwargs: {"provider" => "provider"}, line: 6}
    ]))
    expect(top.sign_ins.map(&:to_h)).to(eq([{helper: "sign_in_as_provider", argument: "provider", line: 10, let: "provider"}]))
    expect(top.sign_ins.first.role_hint).to(eq("provider"))
    expect(top.before_lines).to(eq(["driven_by :cuprite", "sign_in_as_provider(provider)"]))
    expect(top.examples).to(eq(["lists the discounts"]))
    ctx = top.children.first
    expect(ctx.kind).to(eq("context"))
    expect(ctx.path).to(eq(["Provider discounts", "when the discount is archived"]))
    expect(ctx.indent).to(eq(2))
    expect(ctx.visible_lets.map(&:name)).to(eq(%w[provider discount archived]))
    expect(ctx.visible_sign_ins.size).to(eq(1))
    expect(file.find_block(["when the discount is archived"])).to(eq(ctx))
    expect(file.find_block(nil)).to(eq(top))
  end

  it "parses the unparenthesised Studiz style too" do
    file = described_class.parse(fixture("student_profile_spec.rb"))
    top = file.blocks.first
    expect(top.description).to(eq("Student profile"))
    expect(top.lets.first.to_h).to(include(name: "student", factory: "student", kwargs: {"automatic_verified" => "true"}))
    expect(top.sign_ins.first.let_name).to(eq("student"))
  end

  it "inserts before the block's `end` with the block's indentation and a separating blank line" do
    file = described_class.parse(fixture("provider_discounts_spec.rb"))
    ctx = file.find_block(["when the discount is archived"])
    text, line = file.insertion_for(ctx, ["it 'x' do", "  visit(root_path)", "end"])
    expect(line).to(eq(ctx.last_line))
    expect(text).to(eq(["\n", "    it 'x' do\n", "      visit(root_path)\n", "    end\n"]))
    content = file.content_with(ctx, ["it 'x' do", "end"])
    expect(content.lines[ctx.last_line - 1..ctx.last_line + 2].join).to(eq("\n    it 'x' do\n    end\n  end\n"))
    RubyVM::InstructionSequence.compile(content)
  end
end
