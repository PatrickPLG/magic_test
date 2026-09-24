require "tempfile"

module MagicTest
  # Writes generated code directly above the `magic_test` call, re-reading the
  # file every time and locating the call by its source text, so the editor
  # saving the file mid-session cannot corrupt the insert position. Writes are
  # atomic (temp file + rename) and refused when the result would not parse.
  class SpecWriter
    class Error < MagicTest::Error; end

    SEARCH_WINDOW = 200

    attr_reader :path, :line, :source_line

    # @param path [String] absolute path of the spec
    # @param line [Integer] 1-based line of the `magic_test` call when the session started
    # @param source_line [String] the exact text of that line
    def initialize(path:, line:, source_line:)
      @path = path
      @line = line.to_i
      @source_line = source_line.to_s
    end

    # Inserts `lines` (unindented) above the magic_test line. Returns the new
    # 1-based line number of the magic_test call.
    def insert_above(lines)
      lines = Array(lines)
      return @line if lines.empty?
      content = File.read(path)
      file_lines = content.lines
      index = locate(file_lines)
      raise Error, "could not find `#{source_line.strip}` near line #{line} of #{path}" unless index
      indentation = file_lines[index][/\A[ \t]*/]
      insert = lines.map { |l| l.empty? ? "\n" : "#{indentation}#{l}\n" }
      new_lines = file_lines[0...index] + insert + file_lines[index..]
      new_content = new_lines.join
      check_syntax!(new_content)
      atomic_write(new_content)
      @line = index + insert.size + 1
    end

    # Ruby that the file would contain after the insert, without writing it.
    def preview(lines)
      file_lines = File.read(path).lines
      index = locate(file_lines) or return nil
      indentation = file_lines[index][/\A[ \t]*/]
      (file_lines[0...index] + Array(lines).map { |l| l.empty? ? "\n" : "#{indentation}#{l}\n" } + file_lines[index..]).join
    end

    def check_syntax!(content)
      RubyVM::InstructionSequence.compile(content, path)
      true
    rescue SyntaxError => e
      raise Error, "refusing to write #{path}: #{e.message.lines.first&.strip}"
    end

    # Removes the magic_test line itself (used by the golden-flow verifier).
    def remove_call!
      file_lines = File.read(path).lines
      index = locate(file_lines) or raise Error, "could not find `#{source_line.strip}` in #{path}"
      file_lines.delete_at(index)
      atomic_write(file_lines.join)
    end

    private

    # Nearest line whose stripped text equals the recorded source line,
    # searching outward from the last known position.
    def locate(file_lines)
      wanted = source_line.strip
      return nil if wanted.empty? || file_lines.empty?
      origin = (line - 1).clamp(0, file_lines.size - 1)
      return origin if file_lines[origin]&.strip == wanted
      (1..SEARCH_WINDOW).each do |delta|
        [origin - delta, origin + delta].each do |i|
          next if i.negative? || i >= file_lines.size
          return i if file_lines[i].strip == wanted
        end
      end
      file_lines.index { |l| l.strip == wanted }
    end

    def atomic_write(content)
      dir = File.dirname(path)
      mode = File.stat(path).mode
      Tempfile.create([".magic_test", ".rb"], dir) do |tmp|
        tmp.write(content)
        tmp.flush
        tmp.fsync
        File.chmod(mode, tmp.path)
        File.rename(tmp.path, path)
      end
    end
  end
end
