# frozen_string_literal: true

module MagicTest
  module Testing
    # Helpers for scripts that drive the browser wizard's four steps like a
    # person (golden UI flows and the UI specs). Mixed into the wizard's
    # ScriptDSL by the script that uses them: `extend MagicTest::Testing::WizardUi`.
    # Every action goes through real clicks and typing; waits poll the page.
    module WizardUi
      def ui
        @ui_human ||= human
      end

      def wait_css(css, timeout: 20)
        wait_until(timeout: timeout) { page.has_css?(css) }
      end

      def current_step
        page.evaluate_script("(document.querySelector('#steps li.current') || {}).id || ''").sub("step-", "").to_i
      end

      def preview_text
        page.evaluate_script("document.getElementById('preview').textContent")
      end

      # ---- step 1 ---------------------------------------------------------------

      def pick_starter(id)
        wait_css("#w-source-starter-#{id}")
        ui.click("#w-source-starter-#{id}")
        wait_until { page.evaluate_script("document.getElementById('w-source-starter-#{id}').classList.contains('selected')") }
      end

      def pick_template(slug)
        wait_css("#w-source-template-#{slug}")
        ui.click("#w-source-template-#{slug}")
      end

      def pick_last_plan
        wait_css("#w-source-last")
        ui.click("#w-source-last")
      end

      def describe_test(text)
        wait_css("#w-description")
        ui.click("#w-description").select_all.type(text)
      end

      def new_file(path)
        wait_css("#w-target-new")
        ui.click("#w-target-new") unless page.evaluate_script("document.getElementById('w-target-new').classList.contains('on')")
        wait_css("#w-path")
        ui.click("#w-path").select_all.type(path)
      end

      def existing_file(path)
        wait_css("#w-target-existing")
        ui.click("#w-target-existing")
        wait_css("#w-path")
        ui.click("#w-path").select_all.type(path)
        wait_css("#w-block", timeout: 20)
      end

      # Picks a block of the file's tree by its label ("context 'Visuals' (line 34)").
      def pick_block(label)
        wait_css("#w-block")
        option = page.find("#w-block").all("option").find { |o| o.text.include?(label) } or raise "no block option containing #{label.inspect}; have #{page.find("#w-block").all("option").map(&:text)}"
        option.select_option
      end

      # ---- step 2 ---------------------------------------------------------------

      def pick_role(class_name)
        wait_css("#w-role")
        page.find("#w-role").find("option[value='#{class_name}']").select_option
        wait_css("#w-role-let") if class_name.to_s != ""
      end

      def set_trait(prefix, trait, on: true)
        wait_css("##{prefix}-trait-#{trait}")
        box = page.find("##{prefix}-trait-#{trait}")
        ui.click("##{prefix}-trait-#{trait}") if box.checked? != on
      end

      def add_record(factory)
        wait_css("#w-factory-filter")
        ui.click("#w-factory-filter").select_all.type(factory)
        page.find("#w-factory").find("option[value='#{factory}']").select_option
        ui.click("#w-add-model")
        wait_until { page.has_css?("[id^='w-model-'][id$='-let']") }
      end

      def set_attribute(model_index, name, value)
        ui.click("#w-model-#{model_index}-attr-add").type(name)
        ui.press("Enter")
        wait_css("#w-model-#{model_index}-attr-#{name}")
        ui.click("#w-model-#{model_index}-attr-#{name}").type(value)
      end

      # ---- step 3 ---------------------------------------------------------------

      def pick_route(name, params = {})
        wait_css("#w-route-filter")
        ui.click("#w-route-filter").select_all.type(name)
        page.find("#w-route").find("option[value='#{name}']").select_option
        params.each do |part, let|
          wait_css("#w-param-#{part}")
          page.find("#w-param-#{part}").find("option[value='#{let}']").select_option
        end
        page.find("#w-route").find("option[value='#{name}']")
      end

      def tick(id, on: true)
        wait_css("##{id}")
        ui.click("##{id}") if page.find("##{id}").checked? != on
      end

      # ---- navigation -----------------------------------------------------------

      def next_step
        from = current_step
        ui.click("#next")
        wait_until(timeout: 15) { current_step == from + 1 || page.has_css?("#next[disabled]") == false && page.evaluate_script("document.getElementById('next').textContent").include?("Fix") }
        raise "stuck on step #{from}: #{page.evaluate_script("document.getElementById('issues').textContent")}" if current_step == from
      end

      def back_step
        ui.click("#back")
      end

      # ---- step 4 ---------------------------------------------------------------

      def run_preflight(timeout: 90)
        wait_css("#w-review-path")
        wait_until { page.evaluate_script("document.getElementById('preflight').disabled") == false }
        ui.click("#preflight")
        wait_until(timeout: timeout) { %w[preflighted planning].include?(state[:status]) && state[:preflight] }
        wait_until { page.has_css?("#preflight-ok") || page.has_css?("#preflight-failed") }
        state[:preflight]
      end

      def start_recording
        wait_until { page.evaluate_script("document.getElementById('start').disabled") == false }
        ui.click("#start")
        wait_until { state[:status] == "recording" }
      end

      # "Save as template" through the real button (the name prompt is answered by a stub).
      def save_template(name)
        wait_css("#w-save-template")
        page.execute_script("window.prompt = function () { return #{name.to_json}; }")
        ui.click("#w-save-template")
        wait_until { page.evaluate_script("document.getElementById('w-template-saved').textContent").include?("saved:") }
      end
    end
  end
end
