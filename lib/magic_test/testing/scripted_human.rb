# frozen_string_literal: true

module MagicTest
  module Testing
    # Drives a Cuprite session the way a person would: every interaction goes
    # through Chrome DevTools Protocol input events (Input.dispatchMouseEvent,
    # Input.dispatchKeyEvent, Input.insertText, DOM.setFileInputFiles), so the
    # DOM events the recorder sees carry `isTrusted: true`.
    #
    # Capybara's own `fill_in`/`select`/`click` under Cuprite are partly
    # implemented with JavaScript-dispatched (untrusted) events, which the
    # recorder ignores on purpose. Element lookup still uses Capybara finders
    # (with waiting); only the input itself is CDP-native.
    class ScriptedHuman
      MODIFIER_KEYS = %i[control shift alt meta].freeze

      attr_reader :page

      def initialize(page)
        @page = page
      end

      # Address-bar navigation (Page.navigate), not a click.
      def visit(path)
        page.visit(path)
        self
      end

      def click(locator, **options)
        node_for(locator, **options).click
        self
      end

      def click_on(text, **options)
        ferrum_node(page.find(:link_or_button, text, **options)).click
        self
      end

      def right_click(locator, **options)
        node_for(locator, **options).click(mode: :right)
        self
      end

      def hover(locator, **options)
        node = node_for(locator, **options)
        node.scroll_into_view
        x, y = node.find_position
        mouse.move(x: x, y: y)
        self
      end

      def focus(locator, **options)
        node_for(locator, **options).focus
        self
      end

      # Clicks the element, selects its current content and types the text.
      def fill(locator, text, **options)
        click(locator, **options)
        select_all
        type(text)
        self
      end

      # Types into whatever is focused, key by key (trusted keydown/keypress/input).
      def type(text)
        keyboard.type(text)
        self
      end

      # Presses a special key, e.g. :enter, :backspace, :tab, :down, :home, :end.
      def press(key, *modifiers)
        keyboard.type(modifiers.empty? ? key : [*modifiers, key])
        self
      end

      def select_all
        press("a", :control)
      end

      # Paste/autofill-like input: no key events, just an `input` event with
      # inputType "insertText", exactly what Chrome does for a clipboard paste.
      def paste(text)
        ferrum_page.command("Input.insertText", text: text)
        self
      end

      def attach(locator, path, **options)
        node_for(locator, visible: :all, **options).select_file(path.to_s)
        self
      end

      # Native <select>: keyboard driven, like a person tabbing through a form.
      # Chrome changes the value and fires trusted input/change on arrow keys.
      def native_select(locator, option_text, **options)
        element = page.find(:select, locator, **options)
        options_texts = element.all("option", visible: :all).map(&:text)
        target = options_texts.index(option_text) or raise ArgumentError, "no option #{option_text.inspect} in #{options_texts.inspect}"
        current = options_texts.index(element.value.to_s.empty? ? options_texts.first : element.find("option[value=#{element.value.inspect}]", visible: :all).text)
        node = ferrum_node(element)
        node.focus
        steps = target - current
        key = steps.positive? ? :down : :up
        steps.abs.times { keyboard.type(key) }
        self
      end

      # Highlights the text of an element (a selection is not an event).
      def select_text(locator, **options)
        page.execute_script("window.getSelection().removeAllRanges(); window.getSelection().selectAllChildren(arguments[0]);", page.find(locator, **options))
        self
      end

      def scroll_to(locator, **options)
        node_for(locator, **options).scroll_into_view
        self
      end

      def keyboard
        ferrum_page.keyboard
      end

      def mouse
        ferrum_page.mouse
      end

      def ferrum_page
        page.driver.browser.page
      end

      def ferrum_node(capybara_element)
        capybara_element.native.node
      end

      private

      def node_for(locator, **options)
        element = locator.is_a?(Capybara::Node::Element) ? locator : page.find(:css, locator, **options)
        ferrum_node(element)
      end
    end
  end
end
