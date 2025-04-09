# Magic Test

Magic Test allows you to write Rails system tests interactively through a combination of trial-and-error in a debugger session and also just simple clicking around in the application being tested, all without the slowness of constantly restarting the testing environment. You can [see some videos of it in action](https://twitter.com/andrewculver/status/1366062684802846721)!

> **Note:** This is a **fork** of the original `magic_test` gem containing significant enhancements and fixes focused on improving the reliability and robustness of the generated test code.

Magic Test was originally created by [Andrew Culver](http://twitter.com/andrewculver) and [Adam Pallozzi](https://twitter.com/adampallozzi).

## Key Enhancements in This Fork

This version of Magic Test introduces several major improvements over the original:

1.  **Significantly Improved Selector Generation:**
    *   The core logic has been revamped to drastically reduce reliance on brittle XPath selectors.
    *   A new heuristic approach prioritizes robust, semantic selectors:
        *   Unique IDs (`#my-element`)
        *   `name` attributes for form elements (`input[name="user[email]"]`)
        *   Combinations of meaningful CSS classes (while attempting to filter out common utility classes like those from Bootstrap/Tailwind).
        *   Falls back to more stable CSS selectors (like `tag[attribute]` or `tag.class`) before resorting to positional selectors like `:nth-of-type`.
    *   **Benefit:** Generated tests are far more resilient to minor UI structure changes.

2.  **Automatic `within` Block Generation:**
    *   When a globally unique selector cannot be found for an interacted element, Magic Test now automatically searches up the DOM for a uniquely identifiable ancestor.
    *   If a suitable ancestor (e.g., identified by ID or semantic class) is found, and the target element can be uniquely identified *relative* to that ancestor (using CSS selectors like `.class`, `tag.class:not(.other)`, or `tag:nth-of-type(n)`), Magic Test generates a nested `within` block.
    *   **Example Output:**
        ```ruby
        within('#ancestor-id') do
          find('.relative-target-class').click
        end
        ```
    *   **Benefit:** Improves test structure, readability, and robustness by leveraging contextual scoping, further reducing the need for manual refinement.

3.  **Enhanced Chosen.js Support:**
    *   Provides more comprehensive recording for interactions with [Chosen.js](https://harvesthq.github.io/chosen/) widgets.
    *   Supports:
        *   Opening/closing dropdowns.
        *   Searching within the dropdown.
        *   Selecting options in both single and multi-selects.
        *   **Deselecting options** in multi-selects.

4.  **Programmatic Click Filtering:**
    *   Uses `event.isTrusted` to differentiate between direct user clicks and clicks triggered programmatically by application JavaScript (e.g., `element.click()`).
    *   **Benefit:** Prevents the recording of unwanted secondary events often triggered by application JS (like hidden form submissions), leading to cleaner and more accurate test steps focused on user actions.

5.  **Improved SVG Click Handling:**
    *   Clicks on SVG elements or their children (`<path>`, etc.) nested within interactive container elements (e.g., a `div` acting as a button) are now correctly attributed to the container.
    *   **Benefit:** Allows the selector generation logic to find robust selectors for the container element instead of failing on the SVG itself.

6.  **Session Reliability Fixes:**
    *   Addresses issues where stale events could persist in browser `sessionStorage` between `flush` commands within a single `pry` session.
    *   Ensures `flush` only processes events recorded since the last flush or the start of the `pry` session.

These enhancements aim to make Magic Test a more powerful and reliable tool for generating robust Rails system tests with less manual intervention required after recording.

## Sponsored By (Original Gem)

<a href="https://bullettrain.co" target="_blank"><img src="https://github.com/CanCanCommunity/cancancan/raw/develop/logo/bullet_train.png" alt="Bullet Train" width="400"/></a>
<br/>
<br/>

> Would you like to support Magic Test development and have your logo featured here? [Reach out!](http://twitter.com/andrewculver)

## Installation (This Fork)

**Important:** Replace the original `magic_test` gem line in your `Gemfile`'s `:test` group with a reference to this fork (adjust `:github`, `:branch`, or path as needed):

```ruby
# Example using GitHub:
gem 'magic_test', github: 'your-github-username/magic_test', branch: 'your-feature-branch', group: :test
# Or using a local path:
# gem 'magic_test', path: '../path/to/your/magic_test_fork', group: :test
```

Then run the following in your shell:

```bash
bundle install
```

If you haven't run the original installer before, run the install generator:

```bash
# Only run this if you didn't run it for the original gem
rails g magic_test:install
```

This will perform the initial setup (sample test, configuration updates, layout snippet). Review the changes carefully.

**Ensure Layout Snippet is Present:**
Make sure the following snippet is present just before the closing `</head>` tag in your relevant layout files (`app/views/layouts/**/*.html.erb`):

```ruby+erb
<%= render 'magic_test/support' if Rails.env.test? %>
```

**(Optional) Generate Binstubs:**
Run `bundle binstubs magic_test` to create `bin/magic`.

## Usage

The core usage remains similar to the original Magic Test:

1.  **Add `magic_test`:** Place the `magic_test` method call in your system test file where you want to start the interactive session.
2.  **Run Test:** Execute your test using the `bin/magic` binstub (or `MAGIC_TEST=1 rails test ...`):
    ```bash
    bin/magic test test/system/your_test_file.rb
    # or for RSpec:
    # bin/magic spec spec/system/your_spec_file.rb
    ```
3.  **Interact:** This opens three windows:
    *   **Debugger (Pry):** Interactively write/run Capybara commands. Type `ok` to save the last command/block.
    *   **Browser:** Click around your application. Interactions are recorded.
    *   **Editor:** Watch the test file update (mostly).
4.  **Record Actions:** Click links, buttons, fill forms, select/deselect Chosen options, etc., in the browser. Magic Test will attempt to record these actions using the improved heuristics.
5.  **Generate Assertions:** Highlight text and press `Ctrl+Shift+A` (or `Cmd+Shift+A` on Mac) or Right-Click to generate `assert page.has_content?` or `expect(page).to have_content` assertions.
6.  **Flush Actions:** Go to the debugger console and type `flush`. Recorded browser interactions (and generated assertions) since the last `flush` will be converted to Capybara code and written to your test file below the `magic_test` line, using the enhanced selector and `within` block generation logic.
7.  **Continue/Exit:** Continue interacting and flushing, or press `Ctrl+D` in the debugger to exit the session and finish the test run.
8.  **Cleanup:** Remember to remove the `magic_test` call from your test file once you're finished writing it.

> **Key Difference:** Thanks to the enhancements, the code generated by `flush` should be significantly more robust, often requiring less manual cleanup, especially regarding selectors and scoping.

## Contributing

Bug reports and pull requests are welcome on GitHub (link to your fork).

## License

The Ruby Gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
