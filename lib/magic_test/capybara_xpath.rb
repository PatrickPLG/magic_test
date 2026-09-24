require "capybara"

module MagicTest
  # Compiles the XPath Capybara itself uses for its semantic selectors, with a
  # placeholder in the locator position, so the browser can count matches with
  # Capybara's own matching semantics (`Capybara.exact`, `match: :smart`,
  # partial text, normalised whitespace) instead of a hand-rolled imitation.
  #
  # Two variants per selector: `exact` (`XPath#is` becomes `=`) and `partial`
  # (`contains`). `match: :smart` means: use the exact matches when there are
  # any, otherwise the partial ones; more than one is Ambiguous.
  module CapybaraXPath
    PLACEHOLDER = "__MAGIC_TEST_LOCATOR__"
    SELECTORS = %i[link_or_button link button fillable_field select checkbox radio_button field file_field option].freeze

    module_function

    def templates
      SELECTORS.each_with_object({}) do |name, memo|
        memo[name] = {
          "exact" => query(name).xpath(true),
          "partial" => query(name).xpath(false),
          "exact_supported" => query(name).supports_exact? != false,
          # Node filters Capybara applies in Ruby after the XPath ran.
          "filters" => node_filters(name)
        }
      end
    end

    def query(name)
      Capybara::Queries::SelectorQuery.new(name, PLACEHOLDER, session_options: Capybara.session_options)
    end

    def node_filters(name)
      case name
      when :link then %w[visible]
      when :link_or_button then %w[visible disabled_unless_link]
      when :option then %w[visible]
      else %w[visible disabled]
      end
    end

    def session_settings
      {
        "exact" => Capybara.exact,
        "match" => Capybara.match.to_s,
        "ignore_hidden_elements" => Capybara.ignore_hidden_elements,
        "enable_aria_label" => Capybara.enable_aria_label,
        "default_max_wait_time" => Capybara.default_max_wait_time
      }
    end

    # Ruby-side count with the same semantics, used by the parity suite and by
    # "Replay pending" to prove locators resolve in the live session.
    def smart_count(node, selector, locator, **options)
      exact = node.all(selector, locator, exact: true, wait: 0, **options).size
      return exact if exact.positive?
      node.all(selector, locator, exact: false, wait: 0, **options).size
    end
  end
end
