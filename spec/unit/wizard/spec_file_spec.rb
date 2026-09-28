require "rails_helper"
require "magic_test/wizard"
require "digest"

RSpec.describe(MagicTest::Wizard::SpecFile) do
  def fixture(name)
    dir = Pathname(File.expand_path("../../../tmp/wizard_spec_fixtures", __dir__)) # outside spec/, so RSpec never loads the copies
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
    file = described_class.parse(fixture("legacy_unparenthesised_spec.rb"))
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

  # B4 (1.2): Studiz files nest describe/context with repeated names, so a
  # block is picked from the parsed tree and referenced exactly (full path,
  # header hash, line); a tail match on descriptions took the first hit.
  describe "block references" do
    let(:file) { described_class.parse(fixture("nested_duplicates_spec.rb")) }

    def header(line)
      Digest::SHA1.hexdigest(line)[0, 12]
    end

    it "labels every block with kind, description and line, and gives it an exact reference" do
      visuals = file.all_blocks.select { |b| b.description == "Visuals" }
      expect(visuals.map(&:label)).to(eq(["context 'Visuals' (line 15)", "context 'Visuals' (line 34)"]))
      expect(visuals.first.ref).to(eq({"path" => ["Provider Discounts Page", "index page", "Visuals"], "line" => 15, "header" => header("context 'Visuals' do")}))
      expect(visuals.first.to_h[:ref]).to(eq(visuals.first.ref))
      expect(visuals.first.to_h[:label]).to(eq("context 'Visuals' (line 15)"))
    end

    it "rejects a description that matches several blocks instead of taking the first" do
      expect { file.find_block(["Visuals"]) }.to(raise_error(
        MagicTest::Wizard::AmbiguousBlock,
        "\"Visuals\" matches 2 blocks in #{file.path}: context 'Visuals' (line 15), context 'Visuals' (line 34). Pick one by its line."
      ))
    end

    it "finds a block by its full path even when its line and header have changed" do
      ref = {"path" => ["Provider Discounts Page", "edit page", "Visuals"], "line" => 999, "header" => "stale"}
      expect(file.find_block(ref).first_line).to(eq(34))
    end

    it "uses the header, then the line, to tell apart blocks with the same full path" do
      path = ["Provider Discounts Page", "edit page", "Form operations"]
      expect(file.find_block({"path" => path, "line" => 1, "header" => header("context 'Form operations', :slow do")}).first_line).to(eq(41))
      expect(file.find_block({"path" => path, "line" => 50, "header" => nil}).first_line).to(eq(50))
      expect { file.find_block({"path" => path, "line" => 1, "header" => "nope"}) }.to(raise_error(MagicTest::Wizard::AmbiguousBlock, /"Form operations" matches 2 blocks .*\(line 41\), .*\(line 50\)/))
    end

    it "returns nil for a path that is not in the file, and the outermost block for no reference" do
      expect(file.find_block({"path" => ["Provider Discounts Page", "nope"], "line" => 1, "header" => nil})).to(be_nil)
      expect(file.find_block(["nope"])).to(be_nil)
      expect(file.find_block(nil).first_line).to(eq(4))
    end
  end
end
