# Migrating Studiz to magic_test 1.0

The gem is "gem-locked": the recorder is injected by a Rack middleware and
served by an engine, so the website needs no partials, generators or
initialisers. Everything below is optional clean-up except step 1 and step 4.
Applying all of it takes about five minutes.

## 1. Delete `app/views/magic_test/` (required)

The eight files there are byte-identical copies of the old gem's partials.
They shadow the engine's shim and would load the legacy recorder next to the
new one. The gem detects the directory at boot and prints a warning
(`magic_test: app/views/magic_test overrides the gem's views …`) until it is
gone.

```diff
- app/views/magic_test/_context_menu.html.erb
- app/views/magic_test/_finders.html
- app/views/magic_test/_javascript_helpers.html
- app/views/magic_test/_key_codes.html
- app/views/magic_test/_listeners.html
- app/views/magic_test/_mutation_observer.html
- app/views/magic_test/_storage.html
- app/views/magic_test/_support.html.erb
```

```sh
git rm -r app/views/magic_test
```

## 2. Remove the `render 'magic_test/support'` lines (optional)

The gem still ships `magic_test/_support.html.erb`, now an empty shim, so these
lines are harmless. They are dead code, though, and the mail layouts render
the partial into e-mails. Remove them from:

- `app/views/layouts/_head.html.erb`
- `app/views/layouts/_admin_head.html.erb`
- `app/views/layouts/simple.html.erb`
- `app/views/layouts/mobile.html.erb`
- `app/views/layouts/mobile_web_view.html.erb`
- `app/views/layouts/download_app.html.erb`
- `app/views/layouts/student-id.html.erb`
- `app/views/layouts/ticket_validation.html.erb`
- `app/views/layouts/_studiz-verification.html.erb`
- `app/views/layouts/mails/styled_design*.html.erb`
- `app/views/layouts/mails/support_reply.html.erb` (rendered twice in one document)

```diff
-    <%= render 'magic_test/support' if Rails.env.test? %>
```

The recorder is injected before `</head>` of every HTML response by the
middleware, including the eight layouts that never rendered the partial.

## 3. Remove the manual requires and the module include (optional)

The railtie loads under `MAGIC_TEST` on its own, and `MagicTest::Helpers` is
included into every `type: :system` example group in the test environment
(with or without `MAGIC_TEST`). The old include added the top-level module,
which contains no methods.

`spec/rails_helper.rb`:

```diff
-require 'magic_test' if ENV['MAGIC_TEST']
```

`spec/spec_helper.rb`:

```diff
-require 'magic_test' if ENV['MAGIC_TEST']
 …
-  config.include MagicTest, type: :system
```

## 4. Point the Gemfile at the new version (required)

```diff
-gem 'magic_test', github: 'PatrickPLG/magic_test', branch: 'semantic-selector-improvements', group: :test
+gem 'magic_test', github: 'PatrickPLG/magic_test', branch: 'studiz-recorder-v1', group: :test
```

```sh
bundle update magic_test
bundle binstubs magic_test --force
```

`pry` and `pry-stack_explorer` are no longer runtime dependencies of the gem.
Studiz already bundles pry; the toolbar's **Console** button uses it when
`defined?(Pry)` is true and prints a notice otherwise.

## 5. Keep one `:cuprite` registration (note for the maintainer)

`spec/spec_helper.rb` and `spec/rails_helper.rb` both call
`Capybara.register_driver(:cuprite)`; the later one (1200×800) wins. Keep
only one. It does not matter which for the recorder: rspec-rails'
`driven_by :cuprite` in each spec's `before` re-registers the driver with
Rails defaults anyway, and the gem prepends `MagicTest::CupriteDefaults`
under `MAGIC_TEST` so recording always gets a headed 1200×800 window with a
30 s process timeout. `MAGIC_TEST_HEADLESS=1` keeps it headless (CI, scripted
runs).

## What to expect on the first run

```sh
MAGIC_TEST=1 bin/magic spec/system/provider/discounts_spec.rb
```

1. Chrome opens headed. The spec runs up to the `magic_test` line, then the
   toolbar appears in the page.
2. Click around. Steps show in the toolbar with a confidence badge.
3. **Save** writes the steps directly above the `magic_test` line;
   **Save & finish** also ends the session.
4. Re-run the spec without `MAGIC_TEST`: the recorded steps replay headless.

Existing specs that call `magic_test` keep working: the call is a no-op
unless `MAGIC_TEST` is set.

## Optional follow-up: capybara-lockstep

Studiz has 371 `sleep` calls in its system specs. The generated code and the
`magic_*` helpers never sleep; they rely on Capybara's own waiting. If the
maintainer wants to remove the existing sleeps, `capybara-lockstep` is a
separately-tested website change (it adds a middleware and a JS snippet to
the layouts). The gem does not depend on it and was not tested with it.
