# Changelog

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

### Testing

- Studiz replica fixture app (`spec/fixture_app`) with vendored JS/CSS at the
  pinned versions.
- Scripted human (CDP-trusted input), golden-flow runner (record, generate,
  replay 3×, rubocop), 24 golden flows with committed snapshots, JS unit
  tests in a real browser, Capybara XPath parity suite, Ruby unit specs and
  the Phase 0 audit suite.
- GitHub Actions CI on Ruby 3.2.2 with Chrome; `.travis.yml` removed.
