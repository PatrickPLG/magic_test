require "digest"

module MagicTest
  module Wizard
    class Error < MagicTest::Error; end unless const_defined?(:Error)

    # B4: a block reference that matches several blocks of the file.
    class AmbiguousBlock < Error
      attr_reader :candidates

      def initialize(name, candidates, file)
        @candidates = candidates
        super("#{name.inspect} matches #{candidates.size} blocks in #{file}: #{candidates.map(&:label).join(", ")}. Pick one by its line.")
      end
    end

    # Reads an existing spec with RubyVM::AbstractSyntaxTree (stdlib on 3.2 and
    # 3.3; no parser dependency): describe/context/feature blocks, their lets,
    # before blocks (and the sign-in inside them), examples and line ranges,
    # so the wizard can reuse lets and append an example with the file's
    # indentation.
    class SpecFile
      GROUP_METHODS = %i[describe context feature xdescribe xcontext].freeze
      SIGN_IN_PATTERN = /\A(sign_in_as_[a-z_]+|magic_sign_in|sign_in|login_as)\b/

      Let = Struct.new(:name, :bang, :factory, :traits, :kwargs, :line, :source, :body) do
        def to_h
          {name: name, bang: bang, factory: factory, traits: traits, kwargs: kwargs, line: line}
        end
      end
      SignIn = Struct.new(:helper, :argument, :line, :source) do
        # "provider" from sign_in_as_provider(provider) / magic_sign_in(provider.user)
        def let_name
          argument.to_s[/\A([a-z_][a-z0-9_]*)/, 1]
        end

        # "provider" from sign_in_as_provider; nil for magic_sign_in
        def role_hint
          helper.to_s[/\Asign_in_as_(.+)\z/, 1]
        end

        def to_h
          {helper: helper, argument: argument, line: line, let: let_name}
        end
      end

      class Block
        attr_reader :kind, :description, :first_line, :last_line, :indent, :header, :lets, :before_lines, :sign_ins, :examples, :children, :parent

        def initialize(kind:, description:, first_line:, last_line:, indent:, parent: nil, header: "")
          @kind = kind
          @description = description
          @first_line = first_line
          @last_line = last_line
          @indent = indent
          @header = header
          @parent = parent
          @lets = []
          @before_lines = []
          @sign_ins = []
          @examples = []
          @children = []
        end

        def path
          (parent ? parent.path : []) + [description]
        end

        # "context 'when archived' (line 18)": how errors and pickers name a block.
        def label
          "#{kind} '#{description}' (line #{first_line})"
        end

        # Short hash of the header line ("context 'Visuals', :slow do").
        def header_hash
          Digest::SHA1.hexdigest(header.to_s)[0, 12]
        end

        # B4: what a plan stores to find this block again: the full path, the
        # header hash and the line (path first; header, then line, break ties).
        def ref
          {"path" => path, "line" => first_line, "header" => header_hash}
        end

        # Lets visible inside this block: its own plus its ancestors'.
        def visible_lets
          (parent ? parent.visible_lets : []) + lets
        end

        def visible_sign_ins
          (parent ? parent.visible_sign_ins : []) + sign_ins
        end

        def all_blocks
          [self] + children.flat_map(&:all_blocks)
        end

        def to_h
          {kind: kind, description: description, path: path, first_line: first_line, last_line: last_line, indent: indent, label: label, ref: ref,
           lets: lets.map(&:to_h), sign_ins: sign_ins.map(&:to_h), examples: examples, children: children.map(&:to_h)}
        end
      end

      attr_reader :path, :lines, :blocks

      def self.parse(path)
        new(path).tap(&:parse!)
      end

      def initialize(path)
        @path = path.to_s
        @lines = File.read(@path).lines
        @blocks = []
      end

      def parse!
        ast = RubyVM::AbstractSyntaxTree.parse(lines.join)
        walk(ast, nil)
        self
      end

      def all_blocks
        blocks.flat_map(&:all_blocks)
      end

      # Every block of the file, labelled with its line, for error messages.
      def blocks_summary
        all_blocks.map(&:label).join(", ")
      end

      # The block a plan refers to. nil / [] → the outermost describe. A Hash
      # (Block#ref) matches the full path exactly; among same-path duplicates
      # the header hash, then the line, decides. An Array of descriptions (or a
      # String) is matched as a path suffix, for hand-written plans. Several
      # matches raise AmbiguousBlock; none returns nil.
      def find_block(ref)
        return blocks.first if ref.nil? || ref == "" || ref == [] || (ref.is_a?(Hash) && Array(ref["path"]).empty?)
        if ref.is_a?(Hash)
          path = Array(ref["path"]).map(&:to_s)
          candidates = all_blocks.select { |b| b.path == path }
          return candidates.first if candidates.size <= 1
          by_header = ref["header"].to_s.empty? ? [] : candidates.select { |b| b.header_hash == ref["header"].to_s }
          return by_header.first if by_header.size == 1
          by_line = candidates.select { |b| b.first_line == ref["line"].to_i }
          return by_line.first if by_line.size == 1
          raise AmbiguousBlock.new(path.last, candidates, self.path)
        end
        descriptions = Array(ref).map(&:to_s)
        candidates = all_blocks.select { |b| b.path.last(descriptions.size) == descriptions }
        raise AmbiguousBlock.new(descriptions.join(" > "), candidates, self.path) if candidates.size > 1
        candidates.first
      end

      # Lines to insert (already indented) plus the 1-based line number they go
      # before: the block's closing `end`.
      def insertion_for(block, body_lines)
        indent = " " * (block.indent + 2)
        text = body_lines.map { |l| l.empty? ? "\n" : "#{indent}#{l}\n" }
        # A blank line before the new example unless the block is empty.
        previous = lines[block.last_line - 2].to_s
        text.unshift("\n") if block.last_line - 1 > block.first_line && previous.strip != ""
        [text, block.last_line]
      end

      def content_with(block, body_lines)
        text, before_line = insertion_for(block, body_lines)
        (lines[0...(before_line - 1)] + text + lines[(before_line - 1)..]).join
      end

      private

      def walk(node, parent)
        return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
        if node.type == :ITER && (block = group_block(node, parent))
          node.children.each { |c| walk(c, block) }
          return
        end
        if node.type == :ITER && parent
          case call_name(node.children[0])
          when :let, :let!
            parent.lets << let_from(node)
            return
          when :before, :background
            record_before(node, parent)
            return
          when :it, :scenario, :specify, :example
            parent.examples << (string_arg(node.children[0]) || "(dynamic)")
            return
          end
        end
        node.children.each { |c| walk(c, parent) }
      end

      def group_block(node, parent)
        call = node.children[0]
        name = call_name(call)
        return nil unless GROUP_METHODS.include?(name)
        return nil if call.type == :CALL && !(call.children[0].type == :CONST && call.children[0].children[0] == :RSpec)
        description = string_arg(call) || const_arg(call) || "(dynamic)"
        header_line = lines[node.first_lineno - 1]
        block = Block.new(kind: name.to_s, description: description, first_line: node.first_lineno, last_line: node.last_lineno,
          indent: header_line[/\A */].size, parent: parent, header: header_line.strip)
        (parent ? parent.children : blocks) << block
        block
      end

      def call_name(call)
        return nil unless call.is_a?(RubyVM::AbstractSyntaxTree::Node)
        case call.type
        when :FCALL, :VCALL then call.children[0]
        when :CALL then call.children[1]
        end
      end

      def args_of(call)
        list = case call.type
        when :FCALL then call.children[1]
        when :CALL then call.children[2]
        end
        (list&.type == :LIST) ? list.children.compact : []
      end

      def string_arg(call)
        arg = args_of(call).find { |a| a.type == :STR }
        arg&.children&.first
      end

      def const_arg(call)
        arg = args_of(call).find { |a| %i[CONST COLON2].include?(a.type) }
        arg && source_of(arg)
      end

      def let_from(node)
        call = node.children[0]
        name = args_of(call).find { |a| a.type == :LIT }&.children&.first
        body = node.children[1].children[2] # SCOPE → body
        factory = nil
        traits = []
        kwargs = {}
        create = body if body && %i[FCALL CALL].include?(body.type) && %i[create create_list build].include?(call_name(body))
        if create
          args = args_of(create)
          syms = args.select { |a| a.type == :LIT && a.children[0].is_a?(Symbol) }.map { |a| a.children[0].to_s }
          factory = syms.shift
          traits = syms
          hash = args.find { |a| a.type == :HASH }
          if hash
            pairs = hash.children[0]&.children.to_a.compact
            pairs.each_slice(2) do |k, v|
              next unless k&.type == :LIT
              kwargs[k.children[0].to_s] = %i[VCALL LVAR].include?(v&.type) ? v.children[0].to_s : source_of(v)
            end
          end
        end
        Let.new(name: name.to_s, bang: call_name(call) == :let!, factory: factory, traits: traits, kwargs: kwargs, line: node.first_lineno, source: source_of(node), body: source_of(body))
      end

      def record_before(node, block)
        body = node.children[1].children[2]
        statements = if body.nil?
          []
        else
          ((body.type == :BLOCK) ? body.children : [body])
        end
        statements.each do |st|
          src = source_of(st)
          block.before_lines << src
          next unless SIGN_IN_PATTERN.match?(src)
          helper = call_name(st) || src[/\A\w+/]
          arg = args_of(st).first
          block.sign_ins << SignIn.new(helper: helper.to_s, argument: arg ? source_of(arg) : nil, line: st.first_lineno, source: src)
        end
      end

      def source_of(node)
        return "" unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
        first, last = node.first_lineno, node.last_lineno
        if first == last
          lines[first - 1][node.first_column...node.last_column].to_s
        else
          ([lines[first - 1][node.first_column..]] + lines[first..(last - 2)] + [lines[last - 1][0...node.last_column]]).join
        end.strip
      end
    end
  end
end
