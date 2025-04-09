module MagicTest
  module Support
    def assert_selected_exists
      selected_text = page.evaluate_script("window.selectedText()")
      return if selected_text.blank?

      filepath, line = get_last_caller(caller)

      contents = File.open(filepath).read.lines
      chunks = contents.each_slice(line.to_i - 1 + @test_lines_written).to_a
      indentation = chunks[1].first.match(/^(\s*)/)[0]
      chunks.first << indentation + "assert(page.has_content?('#{selected_text.gsub("'", "\\\\'")}'))" + "\n"
      @test_lines_written += 1
      contents = chunks.flatten.join
      File.open(filepath, "w") do |file|
        file.puts(contents)
      end
    end

    def track_keystrokes
      page.evaluate_script("trackKeystrokes()")
    end

    def flush
      filepath, line = get_last_caller(caller)

      contents = File.open(filepath).read.lines
      slice_point = line.to_i - 1 + @test_lines_written
      chunks = contents.each_slice(slice_point).to_a

      line_after_magic_test = chunks.dig(1, 0)

      if line_after_magic_test
        indentation_match = line_after_magic_test.match(/^(\s*)/)
        indentation = indentation_match ? indentation_match[0] : "  "
      else
        magic_test_line_index = line.to_i - 1
        if magic_test_line_index >= 0 && contents[magic_test_line_index]
           magic_test_line_indentation_match = contents[magic_test_line_index].match(/^(\s*)/)
           magic_test_line_indentation = magic_test_line_indentation_match ? magic_test_line_indentation_match[0] : ""
           indentation = magic_test_line_indentation + "  "
        else
           indentation = "  "
        end
      end

      output = page.evaluate_script("JSON.parse(sessionStorage.getItem('testingOutput') || '[]')")
      puts
      puts "javascript recorded on the front-end looks like this:"
      puts output.inspect
      puts
      puts "(writing generated Capybara steps to `#{filepath}`.)"

      if output && !output.empty?
        output.each do |event_data|
          generated_code = ""
          case event_data["action"]
          when "magic_choose_open"
            original_select_id = event_data["target"]
            chosen_container_selector = "'##{original_select_id}_chosen'"
            generated_code = "find(#{chosen_container_selector}).click"
          when "magic_choose_select"
            original_select_id = event_data["target"]
            option_text = event_data["options"].to_s.gsub("'", "\\\\'")
            chosen_container_selector = "'##{original_select_id}_chosen'"
            generated_code = "find(#{chosen_container_selector}).find('ul.chosen-results li', text: '#{option_text}').click"
          when "magic_choose_search"
            original_select_id = event_data["target"]
            search_text = event_data["options"].to_s.gsub("'", "\\\\'")
            chosen_container_selector = "'##{original_select_id}_chosen'"
            generated_code = "find(#{chosen_container_selector}).find('input.chosen-search-input').set('#{search_text}')"
          else
            action = event_data["action"]
            target = event_data["target"]
            options = event_data["options"]
            generated_code = "#{action} #{target}#{options}"
          end

          unless generated_code.empty?
            chunks.first << indentation + generated_code + "\n"
            @test_lines_written += 1
          end
        end

        contents = chunks.flatten.join
        File.open(filepath, "w") do |file|
          file.puts(contents)
        end
        empty_cache
      else
        puts "`sessionStorage['testingOutput']` was empty or null in the browser. No actions recorded or flushed."
      end
      true
    end

    def ok
      filepath, line = get_last_caller(caller)

      puts "(writing that to `#{filepath}`.)"
      contents = File.open(filepath).read.lines
      chunks = contents.each_slice(line.to_i - 1 + @test_lines_written).to_a
      indentation = chunks[1].first.match(/^(\s*)/)[0]
      get_last.each do |last|
        chunks.first << indentation + last + "\n"
        @test_lines_written += 1
      end
      contents = chunks.flatten.join
      File.open(filepath, "w") do |file|
        file.puts(contents)
      end
      true
    end

    def empty_cache
      page.evaluate_script("sessionStorage.setItem('testingOutput', JSON.stringify([]))")
    rescue Capybara::NotSupportedByDriverError => _
      raise "You need to configure this test (or your test suite) to run in a real browser (Chrome, Firefox, etc.) in order for Magic Test to work. It also needs to run in non-headless mode if `ENV['MAGIC_TEST'].present?`"
    end

    def magic_test
      return unless ENV["MAGIC_TEST"].present?
      empty_cache
      @test_lines_written = 0
      begin
        magic_test_pry_hook
        binding.pry
      rescue
        retry
      end
    end

    private

    def magic_test_pry_hook
      Pry.hooks.add_hook(:before_session, "magic_test") do |output, binding, pry|
        Pry.hooks.delete_hook(:before_session, 'magic_test')
        magic_test_file_index = pry.backtrace.index{|line| line.include?(__FILE__)}
        until pry.backtrace[magic_test_file_index + 1].include?(pry.last_file) do
          pry.run_command('up')
        end
      end
    end

    def get_last
      history_lines = Readline::HISTORY.to_a.last(20)
      i = 2
      last = history_lines.last(2).first
      last_block = [last]
      if last == "end" || last.first(4) == "end "
        i += 1
        last_block.unshift(history_lines.last(i).first)
        until !last_block.first.match(/^(\s+)/) & [0]
          i += 1
          last_block.unshift(history_lines.last(i).first)
        end
      end

      last_block
    end

    def get_last_caller(caller)
      caller.select { |s| s.include?("/test/") || s.include?("/spec/") }
        .reject { |s| s.include?("helper") }
        .first.split(":").first(2)
    end
  end
end
