module MagicTest
  module Codegen
    # Assertion code, always in Capybara's waiting form (`have_no_*` rather
    # than `not_to have_*`).
    module Assertions
      module_function

      def content(text_code, scope: nil)
        "expect(#{scope || "page"}).to(have_content(#{text_code}))"
      end

      def no_content(text_code, scope: nil)
        "expect(#{scope || "page"}).to(have_no_content(#{text_code}))"
      end

      def css(selector_code, text_code: nil, count: nil, visible: nil, scope: nil)
        opts = []
        opts << "text: #{text_code}" if text_code
        opts << "count: #{count}" if count
        opts << "visible: #{visible}" unless visible.nil?
        args = ([selector_code] + opts).join(", ")
        "expect(#{scope || "page"}).to(have_css(#{args}))"
      end

      def no_css(selector_code, scope: nil)
        "expect(#{scope || "page"}).to(have_no_css(#{selector_code}))"
      end

      def field(locator_code, with_code)
        "expect(page).to(have_field(#{locator_code}, with: #{with_code}))"
      end

      def checked_field(locator_code, checked: true)
        checked ? "expect(page).to(have_checked_field(#{locator_code}))" : "expect(page).to(have_unchecked_field(#{locator_code}))"
      end

      def select(locator_code, selected_code)
        "expect(page).to(have_select(#{locator_code}, selected: #{selected_code}))"
      end

      def button(locator_code, disabled: nil)
        opts = disabled.nil? ? "" : ", disabled: #{disabled}"
        "expect(page).to(have_button(#{locator_code}#{opts}))"
      end

      def link(locator_code, href_code: nil)
        opts = href_code ? ", href: #{href_code}" : ""
        "expect(page).to(have_link(#{locator_code}#{opts}))"
      end

      def current_path(helper_code, ignore_query: false)
        opts = ignore_query ? ", ignore_query: true" : ""
        "expect(page).to(have_current_path(#{helper_code}#{opts}))"
      end

      def count_change(model, by)
        "expect { STEPS }.to(change(#{model}, :count).by(#{by}))"
      end

      def model_count(model, count)
        "expect(#{model}.count).to(eq(#{count}))"
      end

      def reload_attr(var, attr, value_code)
        "expect(#{var}.reload.#{attr}).to(eq(#{value_code}))"
      end
    end
  end
end
