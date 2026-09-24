module MagicTest
  # Where `magic_test` was called from: file, line, the exact source line, and
  # the enclosing example's line range when RSpec metadata is available.
  CallSite = Struct.new(:path, :line, :source_line, :example_line, :example_description) do
    def self.capture(locations, example: nil)
      loc = Array(locations).find { |l| !l.path.to_s.include?("/lib/magic_test/") && !l.path.to_s.include?("(eval") } || Array(locations).first
      path = File.expand_path(loc.path)
      line = loc.lineno
      source = File.exist?(path) ? File.read(path).lines[line - 1].to_s.chomp : ""
      new(path: path, line: line, source_line: source,
        example_line: example&.metadata&.dig(:line_number), example_description: example&.full_description)
    end

    def to_h
      {"path" => path, "line" => line, "source_line" => source_line, "example_line" => example_line, "example" => example_description}
    end
  end
end
