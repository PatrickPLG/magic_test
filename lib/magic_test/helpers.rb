module MagicTest
  # Capybara helpers the generated code relies on. Included into every
  # `type: :system` spec in the test environment (not only under MAGIC_TEST),
  # prefixed with `magic_` so they never collide with Studiz's own helpers.
  # No `sleep` anywhere: everything relies on Capybara's synchronisation.
  module Helpers
    class HelperError < StandardError; end

    # Starts a recording session at this point of the spec. A no-op unless
    # MAGIC_TEST is set, so the call can stay in a spec that is still being
    # recorded across runs (everything above it replays, then recording resumes).
    def magic_test
      return unless MagicTest.enabled?
      require "magic_test/session"
      MagicTest::Session.run(page: page, call_site: MagicTest::CallSite.capture(caller_locations(1, 10)), example: (defined?(RSpec) ? RSpec.current_example : nil), context: self)
    end

    # Chosen single/multiple select. `from:` is the label, id or name of the
    # underlying <select>, which Chosen hides.
    #
    #   magic_chosen_select('Fest', from: 'Kategori')
    #   magic_chosen_select('Aktiv', from: 'discount_status')
    def magic_chosen_select(option_text, from:)
      select_el = magic_chosen_underlying_select(from)
      container = magic_chosen_container(select_el, from)
      option = select_el.find(:option, option_text, visible: :all, exact_text: option_text)
      return if option.selected?
      magic_chosen_open(container)
      search = container.first("input.chosen-search-input, .chosen-search input", minimum: 0, wait: 0)
      search&.set(option_text)
      result = container.find("ul.chosen-results li.active-result", text: option_text, exact_text: option_text)
      result.click
      select_el.synchronize(errors: [HelperError]) do
        raise HelperError, "magic_chosen_select: #{option_text.inspect} was clicked but is not selected in #{from.inspect}" unless option.selected?
      end
    end

    # Removes a choice from a Chosen multiple select.
    #
    #   magic_chosen_unselect('Fest', from: 'Kategorier')
    def magic_chosen_unselect(option_text, from:)
      select_el = magic_chosen_underlying_select(from)
      container = magic_chosen_container(select_el, from)
      choice = container.find("ul.chosen-choices li.search-choice", text: option_text, exact_text: option_text)
      choice.find("a.search-choice-close").click
      option = select_el.find(:option, option_text, visible: :all, exact_text: option_text)
      select_el.synchronize(errors: [HelperError]) do
        raise HelperError, "magic_chosen_unselect: #{option_text.inspect} is still selected in #{from.inspect}" if option.selected?
      end
    end

    # flatpickr: sets the date through the widget's own API and verifies the
    # input shows the value.
    #
    #   magic_set_date('Starttidspunkt', '24/09-2026 14:00')
    def magic_set_date(locator, value)
      input = find_field(locator, visible: :all)
      set = page.evaluate_script(<<~JS, input, value)
        (function (input, value) {
          var fp = input._flatpickr;
          if (!fp) {
            var wrapper = input.closest('.flatpickr-wrapper, [data-wrap], .js-datetimepicker-field, .js-datepicker-birthday-field');
            fp = wrapper && wrapper._flatpickr;
          }
          if (!fp) return false;
          fp.setDate(value, true);
          if (input.value !== value) { input.value = value; input.dispatchEvent(new Event('change', {bubbles: true})); }
          return true;
        })(arguments[0], arguments[1])
      JS
      raise HelperError, "magic_set_date: no flatpickr instance on field #{locator.inspect}" unless set
      input.synchronize(errors: [HelperError]) do
        raise HelperError, "magic_set_date: field #{locator.inspect} shows #{input.value.inspect}, expected #{value.inspect}" unless input.value == value
      end
    end

    # Trix editor located by its label, its id, or the `input` attribute of the
    # <trix-editor>. Never by the render-order `trix_input_N` id.
    #
    #   magic_fill_trix('Beskrivelse', with: 'Kom til fredagsbar')
    def magic_fill_trix(locator, with:)
      editor = magic_trix_editor(locator)
      editor.click
      editor.set(with)
      hidden = editor[:input] && first("##{editor[:input]}", visible: :all, minimum: 0, wait: 0)
      editor.synchronize(errors: [HelperError]) do
        text = editor.text(:all)
        raise HelperError, "magic_fill_trix: editor #{locator.inspect} shows #{text.inspect}, expected #{with.inspect}" unless text.include?(with.to_s.strip) || hidden&.value.to_s.include?(ERB::Util.html_escape(with))
      end
    end

    # Cover image upload with the Cropper.js modal (Studiz `_cover_image_upload`).
    #
    #   magic_attach_image('discount[cover_image]', Rails.root.join('spec/fixtures/files/cover.png'))
    def magic_attach_image(locator, path)
      attach_file(locator, path.to_s, make_visible: true)
      magic_apply_crop
    end

    # Applies the crop in `#image-cropper-modal` and waits for it to close.
    def magic_apply_crop
      find("#image-cropper-modal .cropper-container", wait: Capybara.default_max_wait_time * 2)
      find("#image-cropper-modal .image-cropper-apply").click
      assert_no_selector("#image-cropper-modal.show", wait: Capybara.default_max_wait_time * 2)
    end

    # Scopes the block to whichever Studiz modal is open, once its spinner is
    # replaced by real content.
    #
    #   magic_within_modal { fill_in('Navn', with: 'Ida') }
    def magic_within_modal(&block)
      modal = find("#ajax-modal.show, #full-view-modal.show", match: :first)
      modal.assert_no_selector(".spinner-border")
      within(modal, &block)
    end

    # Devise sign-in plus the two cookies Studiz's auth helpers set (Appendix B).
    #
    #   magic_sign_in(provider.user)
    def magic_sign_in(user)
      user.ensure_authentication_token if user.respond_to?(:ensure_authentication_token)
      sign_in(user)
      page.driver.set_cookie("auth_token", user.authentication_token) if user.respond_to?(:authentication_token)
      page.driver.set_cookie("cookie_settings", "necessary")
    end

    private

    def magic_chosen_underlying_select(from)
      find(:select, from, visible: :all)
    rescue Capybara::ElementNotFound => e
      raise HelperError, "magic_chosen_select: no <select> matches #{from.inspect} (by label, id or name): #{e.message}"
    end

    def magic_chosen_container(select_el, from)
      id = select_el[:id].to_s
      if id.present? && has_css?("##{id.gsub(/[^\w]/, "_")}_chosen", wait: 0)
        find("##{id.gsub(/[^\w]/, "_")}_chosen")
      else
        select_el.find(:xpath, "following-sibling::div[contains(@class, 'chosen-container')][1]")
      end
    rescue Capybara::ElementNotFound
      raise HelperError, "magic_chosen_select: #{from.inspect} is not a Chosen select (no .chosen-container next to it)"
    end

    def magic_chosen_open(container)
      return if container[:class].to_s.include?("chosen-with-drop")
      container.find("a.chosen-single, ul.chosen-choices", match: :first).click
      container.synchronize(errors: [HelperError]) do
        raise HelperError, "magic_chosen_select: the Chosen dropdown did not open" unless container[:class].to_s.include?("chosen-with-drop")
      end
    end

    def magic_trix_editor(locator)
      candidates = []
      candidates << "trix-editor##{locator}" if locator.to_s.match?(/\A[\w-]+\z/)
      candidates << "trix-editor[input=#{locator.to_s.inspect}]"
      candidates.each do |css|
        el = first(css, minimum: 0, wait: 0)
        return el if el
      end
      label = first(:xpath, XPath.descendant(:label)[XPath.string.n.contains(locator.to_s)], minimum: 0, wait: 0)
      if label && label[:for].present?
        el = first("trix-editor##{label[:for]}", minimum: 0)
        return el if el
      end
      raise HelperError, "magic_fill_trix: no <trix-editor> matches #{locator.inspect} (by id, label or input attribute)"
    end
  end
end
