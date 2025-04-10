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
      # --- Add logging for file/line --- #
      caller_info = get_last_caller(caller)
      filepath = caller_info[0]
      line = caller_info[1]
      puts "[MagicTest Ruby Debug] Flush target: File=#{filepath}, Line=#{line}" # Log File/Line
      # --------------------------------- #
      puts "[MagicTest Ruby Debug] Flush command started."

      raw_output_json = page.evaluate_script("sessionStorage.getItem('testingOutput')")
      # puts "[MagicTest Ruby Debug] Read from sessionStorage: #{raw_output_json.inspect}" # Keep this less verbose for now

      empty_cache
      puts "[MagicTest Ruby Debug] Called immediate empty_cache after reading."

      contents = File.open(filepath).read.lines
      initial_lines_written_count = @test_lines_written

      # --- Add logging for slice point --- #
      current_slice_point = line.to_i - 1 + initial_lines_written_count
      puts "[MagicTest Ruby Debug] Slice Calculation: line(#{line}) - 1 + initial_lines(#{initial_lines_written_count}) = SlicePoint(#{current_slice_point})"
      # ---------------------------------- #

      current_chunks = contents.each_slice(current_slice_point).to_a
      # --- Add logging for chunks --- #
      puts "[MagicTest Ruby Debug] Created #{current_chunks.size} chunk(s). First chunk size: #{current_chunks[0]&.size || 0}"
      # ----------------------------- #

      line_after_magic_test = current_chunks.dig(1, 0)

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

      # Step 3: Process the data that was read *before* clearing
      output = JSON.parse(raw_output_json || '[]') # Parse the stored JSON
      puts "[MagicTest Ruby Debug] Processing output: #{output.inspect}"
      puts "(writing generated Capybara steps to `#{filepath}`.)"

      if output && !output.empty?
        lines_to_add = [] # Store generated lines
        initial_lines_written_count = @test_lines_written # Track lines added *this* flush

        # --- START: Modify loop for lookahead ---
        output.each_with_index do |event_data, i|
          # Determine next event for lookahead
          next_event_data = output[i+1]
        # --- END: Modify loop for lookahead ---

          base_indentation = indentation # Use indentation calculated earlier
          puts "[MagicTest Ruby Debug] Processing event #{i}: #{event_data.inspect}" # Add basic event log

          # Check if this is a scoped action
          if event_data["scopeType"] == "within"
            scope_selector = event_data["scopeSelector"]
            lines_to_add << base_indentation + "within(#{scope_selector}) do"
            @test_lines_written += 1

            nested_action_data = {
              "action" => event_data["action"],
              "target" => event_data["target"],
              "options" => event_data["options"]
            }
            # NOTE: Lookahead within `within` blocks is not implemented here.
            # generate_action_code needs only event_data and indentation for nested.
            nested_code_lines = generate_action_code(nested_action_data, base_indentation + "  ", nil) # Pass nil for next_event
            nested_code_lines.each do |line|
              lines_to_add << line # Already indented by helper
              @test_lines_written += 1
            end

            lines_to_add << base_indentation + "end"
            @test_lines_written += 1
          else
            # Generate code for a non-scoped action, passing next_event
            # --- START: Handle array return from helper ---
            # action_code = generate_action_code(event_data, base_indentation)
            # lines_to_add << action_code unless action_code.nil? || action_code.empty?
            action_code_lines = generate_action_code(event_data, base_indentation, next_event_data)
            action_code_lines.each do |line|
              lines_to_add << line # Already indented by helper
              @test_lines_written += 1
            end
            # --- END: Handle array return from helper ---
          end
        end

        if lines_to_add.any?
             puts "[MagicTest Ruby Debug] Adding #{lines_to_add.count} line(s) to the file."
             # current_slice_point = line.to_i - 1 + initial_lines_written_count # Moved up
             # current_chunks = contents.each_slice(current_slice_point).to_a # Moved up
             current_chunks[0] = [] unless current_chunks[0]
             current_chunks.first.concat(lines_to_add.map { |l| l + "\n" })

             contents_string = current_chunks.flatten.join
             # --- Add logging for final content --- #
             puts "[MagicTest Ruby Debug] ===== Final Content to Write START ====="
             puts contents_string # Log the exact string being written
             puts "[MagicTest Ruby Debug] ===== Final Content to Write END ====="
             # ------------------------------------ #
             File.open(filepath, "w") do |file|
                 file.puts(contents_string) # Use puts to add trailing newline
             end
             puts "[MagicTest Ruby Debug] File write operation completed."
        else
             puts "[MagicTest Ruby Debug] No new lines generated to add to the file."
        end

        empty_cache
        puts "[MagicTest Ruby Debug] Called final empty_cache after processing/writing."
      else
        puts "[MagicTest Ruby Debug] No output to process (sessionStorage was empty or invalid JSON before immediate clear)."
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
        empty_cache
        binding.pry
      rescue => e
        puts e.backtrace.join("\n")
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

    def generate_action_code(event_data, indentation, next_event_data)
      # Returns an ARRAY of indented code strings
      code_lines = []
      action = event_data["action"]
      target = event_data["target"]
      options = event_data["options"]

      # Common elements for Chosen
      chosen_container_selector = "'##{target}_chosen'"
      chosen_open_line = indentation + "find(#{chosen_container_selector}).click"

      case action
      when "magic_choose_open"
        # Check if next event is select/search for the same target
        should_suppress_open = next_event_data &&
                               ["magic_choose_select", "magic_choose_search"].include?(next_event_data["action"]) &&
                               next_event_data["target"] == target

        if should_suppress_open
          puts "[MagicTest Ruby Debug] Suppressing _open action, handled by next event." # Add log
          # Return empty array, action handled by next step
        else
          puts "[MagicTest Ruby Debug] Generating standalone _open action." # Add log
          code_lines << chosen_open_line
        end

      when "magic_choose_select"
        option_text = options.to_s.gsub("'", "\\\'")
        select_line = indentation + "find(#{chosen_container_selector}).find('ul.chosen-results li', text: '#{option_text}').click"
        puts "[MagicTest Ruby Debug] Generating combined _open + _select action." # Add log
        code_lines << chosen_open_line # Implicit open
        code_lines << select_line      # Actual select

      when "magic_choose_search"
        search_text = options.to_s.gsub("'", "\\\'")
        search_line = indentation + "find(#{chosen_container_selector}).find('input.chosen-search-input').set('#{search_text}')"
        puts "[MagicTest Ruby Debug] Generating combined _open + _search action." # Add log
        code_lines << chosen_open_line # Implicit open
        code_lines << search_line      # Actual search

      when "magic_choose_deselect"
        option_text = options.to_s.gsub("'", "\\\'")
        deselect_line = indentation + "find(#{chosen_container_selector}).find('li.search-choice', text: '#{option_text}').find('a.search-choice-close').click"
        puts "[MagicTest Ruby Debug] Generating _deselect action." # Add log
        code_lines << deselect_line # Deselect doesn't need implicit open

      when "find"
        find_line = nil
        if options&.start_with?(".")
          find_line = indentation + "find(#{target})#{options}"
        else
          # puts "WARN: MagicTest encountered 'find' action without a chained method (.click, .set, etc.): #{event_data.inspect}"
          find_line = indentation + "find(#{target})"
        end
        code_lines << find_line if find_line

      else # Default for click_on, fill_in, etc.
        default_line = indentation + "#{action} #{target}#{options}"
        code_lines << default_line
      end

      # Return the array of indented code lines
      code_lines
    end
  end
end
