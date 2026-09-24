module MagicTest
  module Codegen
    # Renders steps to Ruby lines. Consecutive steps that share a scope chain
    # (`within_window` > `within_frame` > `within`) are merged into one block;
    # dialog wrappers surround single steps.
    class Emitter
      INDENT = "  "

      def initialize(steps, indent: "")
        @steps = steps
        @base = indent
      end

      def render
        lines = []
        render_group(@steps, 0, lines, 0)
        lines.map { |l| l.empty? ? "" : @base + l }
      end

      private

      # Groups steps by the scope at `depth`, recursing into nested scopes.
      def render_group(steps, depth, lines, indent_level)
        i = 0
        while i < steps.size
          step = steps[i]
          scope = step.scopes[depth]
          if scope.nil?
            render_step(step, lines, indent_level)
            i += 1
          else
            j = i
            j += 1 while j < steps.size && steps[j].scopes[depth] == scope && steps[j].scopes[0...depth] == step.scopes[0...depth]
            lines << (INDENT * indent_level) + scope.open
            render_group(steps[i...j], depth + 1, lines, indent_level + 1)
            lines << (INDENT * indent_level) + "end"
            i = j
          end
        end
      end

      def render_step(step, lines, indent_level)
        pad = INDENT * indent_level
        if step.wrapper
          lines << pad + step.review_comment if step.review_comment
          lines << pad + step.wrapper.open
          step.lines.each { |l| lines << pad + INDENT + l }
          lines << pad + "end"
        else
          step.body_lines.each { |l| lines << (l.empty? ? "" : pad + l) }
        end
      end
    end
  end
end
