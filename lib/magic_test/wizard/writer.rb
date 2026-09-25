require "tempfile"
require "fileutils"

module MagicTest
  module Wizard
    # Writes the skeleton (a whole new file or the existing file with the
    # insertion) atomically after a syntax check, and finds the `magic_test`
    # line the recorder will write above.
    module Writer
      module_function

      Written = Struct.new(:path, :line, :source_line)

      def write(skeleton, path)
        content = skeleton.source
        RubyVM::InstructionSequence.compile(content, path)
        FileUtils.mkdir_p(File.dirname(path))
        mode = File.exist?(path) ? File.stat(path).mode : 0o644
        Tempfile.create([".magic_test_wizard", ".rb"], File.dirname(path)) do |tmp|
          tmp.write(content)
          tmp.flush
          tmp.fsync
          File.chmod(mode, tmp.path)
          File.rename(tmp.path, path)
        end
        line = magic_test_line(content, skeleton)
        Written.new(path, line, content.lines[line - 1].chomp)
      rescue SyntaxError => e
        raise Wizard::Error, "refusing to write #{path}: #{e.message.lines.first&.strip}"
      end

      # 1-based line of the `magic_test` call that belongs to the insertion.
      def magic_test_line(content, skeleton)
        lines = content.lines
        from = skeleton.insert_before_line ? skeleton.insert_before_line - 1 : 0
        idx = (from...lines.size).find { |i| lines[i].strip == "magic_test" }
        raise Wizard::Error, "no magic_test line in the written spec" unless idx
        idx + 1
      end
    end
  end
end
