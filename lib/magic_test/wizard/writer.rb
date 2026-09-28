require "tempfile"
require "fileutils"

module MagicTest
  module Wizard
    # Writes the skeleton (a whole new file or the existing file with the
    # insertion) atomically after a syntax check, and finds the `magic_test`
    # line the recorder will write above.
    module Writer
      module_function

      Written = Struct.new(:path, :line, :source_line, :backup)

      BACKUP_DIR = "tmp/magic_test/backups"

      def write(skeleton, path)
        content = skeleton.source
        RubyVM::InstructionSequence.compile(content, path)
        backup = nil
        if File.exist?(path)
          check_insertion!(File.read(path), content, path)
          backup = back_up(path)
        end
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
        Written.new(path, line, content.lines[line - 1].chomp, backup)
      rescue SyntaxError => e
        raise Wizard::Error, "refusing to write #{path}: #{e.message.lines.first&.strip}"
      end

      # B3: the only change allowed to an existing file is one contiguous
      # insertion; every old line must survive, in order, around it.
      def check_insertion!(old, new, path)
        old_lines = old.lines
        new_lines = new.lines
        prefix = 0
        prefix += 1 while prefix < old_lines.size && prefix < new_lines.size && old_lines[prefix] == new_lines[prefix]
        suffix = 0
        while suffix < old_lines.size - prefix && suffix < new_lines.size - prefix &&
            old_lines[old_lines.size - 1 - suffix] == new_lines[new_lines.size - 1 - suffix]
          suffix += 1
        end
        changed = old_lines.size - prefix - suffix
        return if changed.zero? && new_lines.size >= old_lines.size
        raise Wizard::Error, "refusing to overwrite #{path}: the new content changes #{changed} existing line(s) (from line #{prefix + 1}); " \
          "only an insertion into the file is allowed. Nothing was written."
      end

      # Copy of the file as it was, under tmp/magic_test/backups/<timestamp>-<name>.
      def back_up(path)
        dir = File.join(Rails.root.to_s, BACKUP_DIR)
        FileUtils.mkdir_p(dir)
        stamp = Time.now.strftime("%Y%m%d-%H%M%S")
        backup = File.join(dir, "#{stamp}-#{File.basename(path)}")
        backup = File.join(dir, "#{stamp}-#{Process.pid}-#{File.basename(path)}") if File.exist?(backup)
        FileUtils.cp(path, backup)
        backup
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
