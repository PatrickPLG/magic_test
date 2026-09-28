# Changelog

## 1.2.0 (2026-09-28)

Fixes for the wizard's first contact with the real app, then a guided UX.

Bugs found on Studiz (each with a regression test written first):

- B1: the wizard example applies `MagicTest.config.wizard_driven_by` itself
  when the app registers no default driver (Studiz calls `driven_by :cuprite`
  per spec; rspec-rails fell back to selenium and `magic_sign_in` crashed
  with `NoMethodError set_cookie`). `magic_sign_in` now explains a
  non-Cuprite driver and the line to add.
- B2: preflight fails only where RSpec would; a record that saved but is
  invalid afterwards (`create(:provider, :with_cvr)`) is a warning.
- B3: an existing spec file is never rewritten as a new file; the writer
  allows exactly one insertion, backs the old file up under
  `tmp/magic_test/backups/` and refuses anything else; a block that is not in
  the file is a validation error listing the file's blocks.
- B4: blocks are picked from the parsed tree (with line numbers) and stored
  as an exact reference (path, header hash, line); ambiguous descriptions
  are rejected instead of matching the first hit.
- B5: trait rows toggle from their label text or the row (the group wrapper
  was a nested `<label>`), and chosen traits show as removable chips.
- B6: missing-parent warnings only when a NOT NULL parent is not built by the
  factory; a parent the factory builds is a collapsed hint; an optional
  self-referential association (`provider.group_leader`) is never auto-wired;
  proposed let names never collide.
- B7: locators refer to the lets: `within("#discount-card-#{discount.id}")`,
  `click_on(discount.name_da)`, `text: discount.name_da`; text that merely
  contains factory data gets a REVIEW. Record values are snapshotted when
  first seen, so a later `reload` does not change earlier locators.
- B8: DB-change suggestions for any request that changed rows (a rails-ujs
  remote GET included), by diffing the memoised record against the values
  the example started with; the SQL parser accepts Postgres shapes
  (schema-qualified names, query-log comments, CTEs). A Postgres CI job runs
  the DB-change and golden suites.
- B9: after Start the wizard window becomes a status screen (file, live step
  count, bring-to-front, Save / Save & finish) instead of closing.
- Preflight waits for the start page's JavaScript context (Capybara's wait
  time, then one reload) instead of reporting Ferrum's "There's no context
  available" as a failure of the page.

Guided UX:

- Four steps with the skeleton pinned: What & where (starters, templates,
  last plan, blank; new or existing file with its block tree), Who & data
  (learned trait defaults "used in N specs", ranked factory picker,
  associations, overrides), Start page & extras (routes ranked by the
  role's visits, human paths, params auto-filled), Review & preflight (what
  is written where, the insertion highlighted, Save as template).
- Learned defaults from `spec/**/*.rb` (AST, cached per file mtime in
  `tmp/magic_test/catalogue_cache.json`): factory usage, trait combinations,
  sign-in patterns, start pages per role.
- Starters per Studiz role with their last preflight status
  (`tmp/magic_test/starters_status.json`); templates in
  `spec/magic_test/templates/<name>.yml`; `bin/magic new --template <name>
  "description"`.
- `?` hints (`config/hints.yml`) in the wizard and the toolbar, including
  every assertion type, the confidence badges and "Why this locator?".
- The terminal wizard follows: start from a starter/template/last plan,
  learned defaults, save as template, `--tui --template`.
- Fixture app closer to Studiz (CVR-required provider, persisted-but-invalid
  provider, factory-built NOT NULL parent, optional self-reference, clickable
  card with a remote-GET action, a factory that omits its NOT NULL parent,
  nine Studiz-style specs to learn from); `FIXTURE_STUDIZ_MIRROR=1` (no
  default driver) and `FIXTURE_APP_ADAPTER=postgresql`; CI jobs for both.

## 1.1.0 (2026-09-25)

The "new system test" wizard: from nothing to a passing spec without
hand-writing setup.

- `bin/magic new [path]` opens a browser wizard at `/__magic_test/new`
  (test env + MAGIC_TEST only); `bin/magic new --tui` asks the same
  questions in the terminal; `bin/magic new --plan plan.yml` runs a saved
  plan non-interactively (also what the golden wizard flows use). The last
  plan is saved to `tmp/magic_test/last_plan.yml`.
- One engine behind both: a catalogue introspected at runtime (factories
  with traits, role classes, `belongs_to` reflections, named GET routes per
  locale, existing system specs, Flipper flags, fixture files, columns and
  enums), a validator that auto-wires associations, orders lets parents
  first, detects cycles and name collisions and attaches a fix to every
  issue, and a code generator in Studiz house style.
- Writing into existing specs: describe/context blocks are parsed with
  RubyVM::AbstractSyntaxTree; lets are reused when name, factory and traits
  match, renamed from their trait on collision, and a new context with its
  own before is opened when the block lacks the sign-in or the setup.
- Extras: Flipper flags (global or per actor), `travel_to`, viewport
  (desktop/tablet/mobile), cookie consent for guests, `Sidekiq::Testing.inline!`
  around the steps, `ActionMailer::Base.deliveries` assertions, fixture
  files, and a warning about the new-student modals.
- Preflight, mandatory before anything is written: the lets run in order
  inside the real example, every record must be valid and persisted, the
  role must resolve to a user (`config.user_for_role`; Institution →
  leader employee's user), sign-in and the first visit must answer 2xx
  without a login redirect or JS error. Failures name the stage and a fix.
  On success the skeleton is written and recording starts in the same
  session and window.
- The recorder now suggests `ActionMailer::Base.deliveries` and Sidekiq
  enqueued-job assertions when a request delivered mail or enqueued a job.
- `MagicTest.config.user_for_role`, `wizard_driven_by` and `login_paths`.

## 1.0.0 (2026-09-24)

A rewrite of the recorder for the Studiz Rails app. Branch
`studiz-recorder-v1`, based on `semantic-selector-improvements`.

### Integration

- Rack middleware injects the recorder into every HTML response under
  `RAILS_ENV=test` + `MAGIC_TEST`; nothing is injected, mounted or added
  otherwise (proved by `spec/unit/engine_spec.rb`).
- Engine routes under `/__magic_test/*` (script, bootstrap, state, events,
  commands). The controller inherits from `ActionController::Base`.
- `app/views/magic_test/_support.html.erb` is an empty shim; the other legacy
  partials are gone. A host `app/views/magic_test` override is detected and
  reported at boot.
- `MagicTest::Helpers` is included into `type: :system` groups in the test
  environment. `magic_test` is a no-op unless `MAGIC_TEST` is set.
- Cuprite/Ferrum only. Selenium, Minitest, the install generator and the rake
  tasks are removed. Pry is optional.
- `MagicTest::CupriteDefaults` restores a headed 1200×800 window under
  `MAGIC_TEST` even when `driven_by :cuprite` re-registers the driver.

### Recording

- Server-side event log (`POST /__magic_test/events`, keepalive) with a
  sessionStorage fallback; the middleware records params, status, redirects,
  templates, Warden user, flash and DB changes per request.
- `magic_test` blocks on a command queue: save, save & finish, discard,
  replay pending, open console. Code is written directly above the
  `magic_test` line, atomically, after a syntax check.
- Recorder listeners run on `window` in the capture phase, ahead of
  Bootstrap 5's delegated handlers and rails-ujs.
- Native dialogs are intercepted in the page: the human answers in the
  toolbar and the step is wrapped in `accept_confirm`/`dismiss_confirm`/
  `accept_alert`/`accept_prompt`.
- Typing is read from the element (paste, autofill and mid-value edits are
  exact); Enter emits `send_keys(:enter)`; native selects, checkboxes and
  radios, Chosen, flatpickr, Trix, Cropper uploads, Bootstrap modals, toasts,
  iframes and new windows are recorded.
- Hover is an explicit toolbar action (button or Alt+Shift+H).
- Assert mode: click an element for a `have_content`/`have_field`/
  `have_checked_field`/`have_select`/`have_button`/`have_link`/`have_css`
  expectation; highlight text for `have_content`/`have_no_content`.

### Generated code

- Locators ranked green (unique semantic), amber (scoped or CSS) and red
  (positional, with a `# magic_test: REVIEW` comment); uniqueness is
  verified with Capybara's own XPath in the browser.
- Text is resolved back to `I18n.t` keys with template-scope tie-breaking
  and `locale:` when the page was not in the default locale.
- Paths become route helpers with `let` names; ids never appear as literals.
- Suggestions: flash, current path, DB changes (`Model.count`, `reload`),
  toast, modal closed, sign-in and factory setup for the next run.
- Dynamic ids and classes (timestamps, `trix_input_N`, Bootstrap utility and
  state classes, nested-field indexes) are never used.
- `MagicTest.config.ignored_tables` (strings or regexps, always merged with
  the defaults) keeps bookkeeping tables out of DB-change suggestions; the
  defaults now also cover `audits`, `ahoy_visits`, `ahoy_events`,
  `flipper_features`, `flipper_gates` and `live_support_*`.

### Testing

- Studiz replica fixture app (`spec/fixture_app`) with vendored JS/CSS at the
  pinned versions.
- Scripted human (CDP-trusted input), golden-flow runner (record, generate,
  replay 3×, rubocop), 24 golden flows with committed snapshots, JS unit
  tests in a real browser, Capybara XPath parity suite, Ruby unit specs and
  the Phase 0 audit suite.
- GitHub Actions CI on Ruby 3.2.2 with Chrome; `.travis.yml` removed.
