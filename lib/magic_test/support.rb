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
      # puts "[MagicTest Ruby Debug] Flush target: File=#{filepath}, Line=#{line}" # Log File/Line
      # --------------------------------- #
      # puts "[MagicTest Ruby Debug] Flush command started."

      raw_output_json = page.evaluate_script("sessionStorage.getItem('testingOutput')")
      # puts "[MagicTest Ruby Debug] Read from sessionStorage: #{raw_output_json.inspect}"

      empty_cache
      # puts "[MagicTest Ruby Debug] Called immediate empty_cache after reading."

      # Step 3: Process the data that was read *before* clearing
      output = JSON.parse(raw_output_json || '[]') # Parse the stored JSON

      # --- Filter out internal hover events ---
      # original_count = output.size # Remove unused variable
      output.reject! { |event| event['action']&.include?('.hover') }
      # filtered_count = output.size # Remove unused variable
      # puts "[MagicTest Ruby Debug] Filtered #{original_count - filtered_count} hover events." if original_count != filtered_count
      # ----------------------------------------

      # puts "[MagicTest Ruby Debug] Processing filtered output: #{output.inspect}"
      puts "(writing generated Capybara steps to `#{filepath}`.)"

      if output && !output.empty?
        contents = File.open(filepath).read.lines
        initial_lines_written_count = @test_lines_written

        # --- Add logging for slice point --- #
        current_slice_point = line.to_i - 1 + initial_lines_written_count
        # puts "[MagicTest Ruby Debug] Slice Calculation: line(#{line}) - 1 + initial_lines(#{initial_lines_written_count}) = SlicePoint(#{current_slice_point})"
        # ---------------------------------- #

        current_chunks = contents.each_slice(current_slice_point).to_a
        # --- Add logging for chunks --- #
        # puts "[MagicTest Ruby Debug] Created #{current_chunks.size} chunk(s). First chunk size: #{current_chunks[0]&.size || 0}"
        # ----------------------------- #

        line_after_magic_test = current_chunks.dig(1, 0)
        base_indentation = if line_after_magic_test
                             line_after_magic_test[/^\s*/]
                           else
                             contents[line.to_i - 1][/\A\s*/] + '  ' # Indent based on magic_test line + 2 spaces
                           end
        # puts "[MagicTest Ruby Debug] Calculated base indentation: '#{base_indentation}'"

        lines_to_add = [] # Store generated lines
        indices_to_skip = Set.new # Store indices of _open events handled by subsequent combined actions

        # --- Lookahead pass to identify skippable _open events ---
        output.each_with_index do |event_data, i|
          action = event_data['action']
          target = event_data['target']

          if action == 'magic_choose_select' || action == 'magic_choose_search'
            # Look backwards for the most recent matching _open
            j = i - 1
            while j >= 0
              prev_event = output[j]
              if prev_event['action'] == 'magic_choose_open' && prev_event['target'] == target
                # Found the matching _open, mark it for skipping
                indices_to_skip.add(j)
                # puts "[MagicTest Ruby Debug] Marked event #{j} (#{prev_event['action']} for #{target}) to be skipped (handled by event #{i})."
                break # Stop searching backwards once found
              end
              # Optional: Add break conditions if we hit unrelated blocking actions? For now, simple backward search.
              j -= 1
            end
          end
        end
        # puts "[MagicTest Ruby Debug] Indices to skip: #{indices_to_skip.inspect}"
        # ---------------------------------------------------------

        # --- Main processing loop ---
        output.each_with_index do |event_data, i|
          if indices_to_skip.include?(i)
            # puts "[MagicTest Ruby Debug] Skipping event #{i} as planned."
            next # Skip this _open event as it's handled by a combined action later
          end

          puts "[MagicTest Ruby Debug Loop] Processing event #{i}: #{event_data.inspect}"

          # --- START: Re-implement Scope Handling ---
          if event_data['scopeType'] == 'within'
            scope_selector = event_data['scopeSelector'] # Already includes quotes from JS
            nested_action = event_data['action']
            nested_target = event_data['target']
            nested_options = event_data['options']

            puts "[MagicTest Ruby Debug Loop] Detected scoped action for event #{i}."

            lines_to_add << base_indentation + "within(#{scope_selector}) do"
            @test_lines_written += 1

            # Prepare data for the nested action call
            nested_event_data = {
              'action' => nested_action,
              'target' => nested_target,
              'options' => nested_options
            }

            # Generate code for the action *inside* the within block, with increased indent
            nested_generated_code = generate_action_code(nested_event_data, base_indentation + '  ')
            puts "[MagicTest Ruby Debug Loop] Generated nested code for event #{i}: #{nested_generated_code.inspect}"

            if nested_generated_code.any?
              lines_to_add.concat(nested_generated_code)
              @test_lines_written += nested_generated_code.size
              puts "[MagicTest Ruby Debug Loop] Added #{nested_generated_code.size} nested line(s) from event #{i}. Current total lines_to_add: #{lines_to_add.count}"
            else
               puts "[MagicTest Ruby Debug Loop] No nested code generated for event #{i}."
            end

            lines_to_add << base_indentation + "end"
            @test_lines_written += 1

          else
            # --- Not a scoped action, proceed as before ---
            # Call the helper, which now handles combined actions directly based on the action type
            generated_code = generate_action_code(event_data, base_indentation)
            puts "[MagicTest Ruby Debug Loop] Generated code for event #{i}: #{generated_code.inspect}"

            if generated_code.any?
               lines_to_add.concat(generated_code)
               @test_lines_written += generated_code.size
               puts "[MagicTest Ruby Debug Loop] Added #{generated_code.size} line(s) from event #{i}. Current total lines_to_add: #{lines_to_add.count}"
             else
               puts "[MagicTest Ruby Debug Loop] No code generated for event #{i}."
            end
          end
          # --- END: Re-implement Scope Handling ---
        end
        # --------------------------

        if lines_to_add.any?
             # puts "[MagicTest Ruby Debug] Adding #{lines_to_add.count} total line(s) to the file."
             current_chunks[0] = [] unless current_chunks[0]
             current_chunks.first.concat(lines_to_add.map { |l| l + "\n" })

             contents_string = current_chunks.flatten.join
             # --- Add logging for final content --- #
             # puts "[MagicTest Ruby Debug] ===== Final Content to Write START ====="
             # puts contents_string # Log the exact string being written
             # puts "[MagicTest Ruby Debug] ===== Final Content to Write END ====="
             # ------------------------------------ #
             File.open(filepath, "w") do |file|
                 file.puts(contents_string) # Use puts to add trailing newline if needed (join might handle it)
             end
             # puts "[MagicTest Ruby Debug] File write operation completed."
        else
             # puts "[MagicTest Ruby Debug] No new lines generated to add to the file."
        end

        empty_cache
        # puts "[MagicTest Ruby Debug] Called final empty_cache after processing/writing."
      else
        # puts "[MagicTest Ruby Debug] No output to process (sessionStorage was empty or invalid JSON, or only contained filtered events)."
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

    def generate_action_code(event_data, base_indentation)
      action = event_data['action']
      target = event_data['target']
      options = event_data['options']
      code = [] # Always return an array

      case action
      when 'fill_in'
        # Format: fill_in 'label_or_id', with: 'value'
        # JS provides target='label_or_id', options='value'
        code << "#{base_indentation}fill_in #{target}, with: '#{options}'" # Target needs quotes from JS
        # puts "[MagicTest Ruby Debug] Generating fill_in."
      when 'click_on'
        # Format: click_on 'button_link_or_text'
        # JS provides target="'text'", options=""
        code << "#{base_indentation}click_on #{target}" # Target already has quotes from JS
        # puts "[MagicTest Ruby Debug] Generating click_on."
      # --- START: Fix FIND Action ---
      when 'find'
        # Format: find('selector').action_or_chain
        # JS provides target="'selector'", options=".click" or ".send_keys(...)"
        code << "#{base_indentation}find(#{target})#{options}" # Target has quotes, options has method call
        # puts "[MagicTest Ruby Debug] Generating find action."
      # --- END: Fix FIND Action ---
      when 'click' # NOTE: This case might be obsolete if JS always uses find+click or click_on?
         # Keep for now, maybe it's used somewhere?
         # Assumes target is ID/selector that doesn't need quotes
         code << "#{base_indentation}find('#{target}').click"
         # puts "[MagicTest Ruby Debug] Generating click."
      when 'select'
        # Format: select 'option_text', from: 'label_or_id'
        # JS provides target='label_or_id', options='option_text'
        code << "#{base_indentation}select '#{options}', from: #{target}" # Target needs quotes from JS
        # puts "[MagicTest Ruby Debug] Generating select."
      when 'magic_hover'
        # Format: find('selector').hover
        # JS provides target="'selector'", options=""
        code << "#{base_indentation}find(#{target}).hover" # Target includes quotes from JS
      # --- Chosen.js Specific Actions ---
      when 'magic_choose_open'
        # This only runs if it wasn't skipped by the lookahead in flush
        chosen_target = "##{target}_chosen"
        code << "#{base_indentation}find('#{chosen_target}').click"
        # puts "[MagicTest Ruby Debug] Generating standalone magic_choose_open."
      when 'magic_choose_select'
        # Generates the combined open + select sequence
        chosen_target = "##{target}_chosen"
        code << "#{base_indentation}find('#{chosen_target}').click"
        code << "#{base_indentation}find('#{chosen_target}').find('ul.chosen-results li', text: '#{options}').click"
        # puts "[MagicTest Ruby Debug] Generating combined magic_choose_select."
      when 'magic_choose_search'
         # Generates the combined open + search sequence
         chosen_target = "##{target}_chosen"
         code << "#{base_indentation}find('#{chosen_target}').click"
         code << "#{base_indentation}find('#{chosen_target}').find('input').set('#{options}')"
        # puts "[MagicTest Ruby Debug] Generating combined magic_choose_search."
      when 'magic_choose_deselect'
        chosen_target = "##{target}_chosen"
        # Find the specific deselect link for the given option text
        code << "#{base_indentation}find('#{chosen_target}').find('ul.chosen-choices li.search-choice span', text: '#{options}').sibling('a.search-choice-close').click"
        # puts "[MagicTest Ruby Debug] Generating magic_choose_deselect."
      else
        # Maybe log unhandled actions?
        # puts "[MagicTest Ruby Debug] Warning: Unhandled action type '#{action}'"
      end

      code
    end
  end
end
