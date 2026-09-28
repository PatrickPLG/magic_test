require "rails_helper"
require "magic_test/wizard"
require "magic_test/wizard/writer"

# B3 (1.2): an existing spec file was silently replaced when the wizard fell
# back to "new file" mode. The writer is the last line of defence.
RSpec.describe(MagicTest::Wizard::Writer) do
  let(:dir) { Pathname(File.expand_path("../../../tmp/wizard_writer_spec", __dir__)) }
  let(:path) { dir.join("spec/system/existing_spec.rb").to_s }
  let(:existing) do
    <<~RUBY
      require 'rails_helper'

      RSpec.describe('Existing', :js, type: :system) do
        it 'works' do
          visit(root_path)
        end
      end
    RUBY
  end

  Sk = Struct.new(:source, :insert_before_line)

  before do
    FileUtils.rm_rf(dir)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, existing)
  end

  it "refuses to replace an existing file with anything but the file plus one insertion, and leaves it byte-identical" do
    replacement = "require 'rails_helper'\n\nRSpec.describe('New', :js, type: :system) do\n  it 'x' do\n    magic_test\n  end\nend\n"
    expect { described_class.write(Sk.new(replacement, nil), path) }.to(raise_error(MagicTest::Wizard::Error, /refusing to overwrite #{Regexp.escape(path)}: .*only an insertion/))
    expect(File.read(path)).to(eq(existing))
    expect(Dir[dir.join("**/*").to_s].reject { |f| File.directory?(f) }).to(eq([path]))
  end

  it "accepts the file plus one contiguous insertion, and backs the old file up first" do
    lines = existing.lines
    inserted = lines[0...-1] + ["\n", "  it 'new' do\n", "    magic_test\n", "  end\n"] + lines[-1..]
    written = described_class.write(Sk.new(inserted.join, 7), path)
    expect(File.read(path)).to(eq(inserted.join))
    expect(written.line).to(eq(9))
    expect(written.backup).to(match(%r{/tmp/magic_test/backups/\d{8}-\d{6}-existing_spec\.rb\z}))
    expect(File.read(written.backup)).to(eq(existing))
  end

  it "writes a new file without a backup" do
    fresh = dir.join("spec/system/fresh_spec.rb").to_s
    written = described_class.write(Sk.new("RSpec.describe('Fresh') do\n  it 'x' do\n    magic_test\n  end\nend\n", nil), fresh)
    expect(written.backup).to(be_nil)
    expect(written.line).to(eq(3))
  end
end
