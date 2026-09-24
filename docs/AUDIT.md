# Phase 0 audit of the legacy recorder

Base: branch `semantic-selector-improvements`, commit `b74ddef`.
Method: every item in the task's §1 list got a regression test **before** any
code was touched. The tests live in `spec/audit/ruby_side_spec.rb` (pure Ruby)
and `spec/audit/recording_spec.rb` (record → generate in real headless Chrome,
driven with CDP-trusted input through `MagicTest::Testing::ScriptedHuman`).
They are written against a small adapter (`spec/support/recorder_adapter.rb`)
so the same examples run against the legacy recorder and the rewrite.

Command and result against the legacy code (harness commit):

```
$ bin/rspec spec/audit
49 examples, 44 failures
```

The full output is reproduced in the "Evidence" column below. Status legend:
**confirmed** = the regression test fails on legacy for the documented reason;
**refuted** = the test passes on legacy (with the evidence);
**partly** = the claim holds with a nuance.

## Silent data loss / wrong output

| # | Claim | Status | Regression test | Evidence on legacy |
|---|-------|--------|-----------------|--------------------|
| 1 | `within` blocks never generated | **confirmed** | `ruby_side_spec.rb` "audit #1", `recording_spec.rb` "audit #1" | Ruby: scoped event `{scopeType: 'within', scopeSelector: "'#lead_3'", target: "'.js-star'"}` → `find('.js-star').click`. Browser: icon-only row button → `find('.btn.btn-sm.btn-outline-warning.js-star.active').click` (global, and it even captured the transient `.active` class the app's handler added before the bubble-phase listener ran). |
| 2 | highlight-to-assert dropped; only first `'` escaped | **confirmed** | `ruby_side_spec.rb` "audit #2", `recording_spec.rb` "audit #2" | `generate_action_code` returns `[]` for `expect(page).to have_content '…'` events; browser run: selection + Ctrl+Shift+A → generated `""`. |
| 3 | `assert_selected_exists` → `window.selectedText` ReferenceError; Minitest `assert` | **confirmed by inspection** | (method removed by the rewrite; covered by the new assert path in "audit #2") | `selectedText` is declared inside `enableKeyboardShortcuts` (`_context_menu.html.erb:89`), `page.evaluate_script("window.selectedText()")` throws. Line 12 emits `assert(page.has_content?(...))`. |
| 4 | native `<select>` never recorded | **confirmed** | `recording_spec.rb` "audit #4" | keyboard change of `Land` → `""`. |
| 5 | any `label[for]` click → `choose` | **confirmed** | `recording_spec.rb` "audit #5" (4 examples) | text-field label → `choose('Fornavn', allow_label_click: true)`; hidden checkbox → `find('#student_newsletter').click`; radio wrapper → `find('label:nth-of-type(3)').click`. The plain `label[for]` example cannot record anything on legacy at all because the invoice page uses a layout without the partial (see #30). |
| 6 | typing via `keypress` + `value + charStr` | **partly** | `recording_spec.rb` "audit #6" (6 examples) | Backspace: `fill_in 'Fornavn', with: 'Mettes'` (typed "Mettes"+⌫). Paste: `""`. Whitespace: `'hej'` for `"  hej "`. Mid-edit: `'Ø:Hej verden'` for `"Ø: Hej verden"`. **Refuted as stated:** the `\r` from `String.fromCharCode(13)` is always at the end and `.trim()` removes it, so Enter never puts `\r` into a value (test passes on legacy); a textarea newline ends up as a raw LF inside a single-quoted literal, which is valid Ruby, just unreadable. Both tests are kept. |
| 7 | quoting broken throughout | **confirmed** | `ruby_side_spec.rb` "audit #7" (3), `recording_spec.rb` "audit #7" | `fill_in 'Navn', with: 'Studiz' fest'` → SyntaxError; `select 'Ja, tak' os', from: 'Status'` → SyntaxError; chosen `text: 'Kaffe 'og' \ te'` → SyntaxError. |
| 8 | Trix content lost | **confirmed** | `recording_spec.rb` "audit #8" | typing in `<trix-editor>` → only `find('#events_event_description').click`. |
| 9 | file inputs ignored | **confirmed** | `recording_spec.rb` "audit #9" | `attach` on the cover image input → `""`. |
| 10 | Chosen search+select emits open→set→open→select | **confirmed** | `recording_spec.rb` "audit #10" | 4 lines for one pick (`find('#events_event_category_id_chosen').click` twice). |
| 11 | record-dependent ids pass as unique | **confirmed by inspection + test** | `recording_spec.rb` "audit #11" (2) | `findGlobalSelector` accepts any unique `#id` (`_javascript_helpers.html:39-44`). On legacy the invoice example records nothing because of #30; the nested/trix example passes vacuously because Trix/nested typing is not recorded at all. Both remain as regression tests for the rewrite. |
| 12 | `click_on '<textContent>'` without ambiguity check | **confirmed** | `recording_spec.rb` "audit #12" | second row's "Rediger" → `click_on 'Rediger'` while `page.all(:link_or_button, 'Rediger').size == 3`. |
| 13 | bubble-phase click listener on `document` | **confirmed** | `recording_spec.rb` "audit #13" | click inside a card with `onclick="event.stopPropagation()"` → `[]`. |
| 14 | 150 ms global click debounce | **confirmed** | `recording_spec.rb` "audit #14" | two tab clicks → only `click_on 'Arrangør'`. |
| 15 | Enter-submit, `data-confirm`, `alert()` not recorded | **confirmed** | `recording_spec.rb` "audit #15" (3) | Enter → `fill_in '* Besked', with: 'Hej'` + `click_on 'Send'` (a click that never happened; the keypress Enter on the input bubbled into the submit-button branch); `data-confirm` delete → `""`; alert from js.erb → `click_on 'Send påmindelse'` without `accept_alert`. |
| 16 | recorder's prompt uses `window.confirm` | **confirmed** | `recording_spec.rb` "audit #16" | one `Page.javascriptDialogOpening` during highlight-to-assert, auto-accepted by Cuprite. |
| 17 | no `visit` recorded | **confirmed** | `recording_spec.rb` "audit #17" | address-bar navigation → `""`. |

## Robustness / hygiene

| # | Claim | Status | Regression test | Evidence on legacy |
|---|-------|--------|-----------------|--------------------|
| 18 | duplicate globals; `mutationStart(Event)` on every mouseover | **confirmed** | `recording_spec.rb` "audit #18/#19" | two mouse moves → console: `MagicTest: mutationStart called…`, `…called with non-Node element, falling back to document.body`, `mutationEnd called…`, `MutationObserver disconnected.` |
| 19 | hover recording is dead code | **confirmed by inspection** | same | `processMutations` clears its buffer (`_javascript_helpers.html:281-288`); Ruby rejects `.hover` (`support.rb:44`). |
| 20 | global namespace pollution; `const` redeclared | **confirmed** | `recording_spec.rb` "audit #20" (2) | globals present: `ready, isUnique, clickFunction, getPathTo, mutationStart, mutationEnd, initializeMutationObserver, finderForElement, visibleFilter`; double render → `SyntaxError: Identifier 'BOOTSTRAP_CLASS_REGEX' has already been declared`. |
| 21 | right-click leaks listeners and disables the context menu | **confirmed** | `recording_spec.rb` "audit #21" | after two right-clicks a `contextmenu` event is `defaultPrevented`. |
| 22 | line-number arithmetic file writing | **partly** | `ruby_side_spec.rb` "audit #22" (4) | editor inserts a line mid-session → second flush lands 2 lines too low; `magic_test` on line 1 → `ArgumentError: invalid slice size`; `File.open(...).read` leaves the handle open. **Refuted as stated:** `ok` with `magic_test` as the last line does *not* crash (`chunks[1]` exists); the nil crash needs a stale line offset, which the mid-session-save test already covers. |
| 23 | `get_last_caller` rejects "helper" frames | **confirmed** | `ruby_side_spec.rb` "audit #23" (2) | support-file caller skipped in favour of the spec frame; project path containing "helper" → `NoMethodError: undefined method 'split' for nil`. |
| 24 | `rescue => e; retry` loops forever | **confirmed** | `ruby_side_spec.rb` "audit #24" | deterministic `RuntimeError` → `Timeout::Error` after 2 s instead of the error. |
| 25 | `exe/magic spec <file>` runs the whole suite | **confirmed** | `ruby_side_spec.rb` "audit #25" | fake rspec received `["spec", "spec/system/my", "spec_spec.rb"]`. |
| 26 | helpers only included under `MAGIC_TEST` | **confirmed** | `ruby_side_spec.rb` "audit #26" | `type: :system` group ancestors do not include any gem module when `MAGIC_TEST` is unset. |
| 27 | placeholder test suite | **confirmed** | `ruby_side_spec.rb` "audit #27" | `test/magic_test_test.rb#test_it_does_something_useful` is `assert false`. |
| 28 | `<script text=…>`, console noise, `.quantity-btn` | **confirmed** | `ruby_side_spec.rb` "audit #28", `recording_spec.rb` "audit #28" | typo in `_javascript_helpers.html:1`; page load logs `🪄 Magic Test activated…`, `initializeMutationObserver called`, `MutationObserver initialized successfully:`. `.quantity-btn` (`_javascript_helpers.html:390`) has no explanation anywhere in the history; dropped. |

## Found while auditing (not on the list)

| # | Finding | Regression test | Evidence |
|---|---------|-----------------|----------|
| 29 | `magic_test` before the first `visit` crashes: `empty_cache` touches `sessionStorage` on `about:blank` | `recording_spec.rb` "audit #29" | `SecurityError: Failed to read the 'sessionStorage' property from 'Window'`. |
| 30 | Layouts without the partial record nothing (Studiz has 8 such layouts) | `recording_spec.rb` "audit #5 … plain label[for]" and "audit #11 … record id" run on the bare layout | both produce `""` on legacy. Fixed by middleware injection. |
| 31 | The bubble-phase listener sees the DOM *after* app handlers ran, so transient state classes leak into selectors | `recording_spec.rb` "audit #1" | `.js-star.active` in the emitted selector although the human clicked an inactive star. |
| 32 | Enter inside a text input is mis-recorded as a click on the submit button | `recording_spec.rb` "audit #15 … Enter" | `click_on 'Send'` emitted for a keypress. |
| 33 | `sessionStorage` is never initialised by the JS (`initializeStorage` is defined but never called); the first Ctrl+Shift+A before a `flush` throws `TypeError: null.push` | covered by the rewrite's server-side event log | `_storage.html` / `_context_menu.html.erb:39`. |
| 34 | `rspec-rails`' `driven_by :cuprite` (in every Studiz spec's `before`) **re-registers** the `:cuprite` driver with Rails defaults, discarding `js_errors`, `window_size` and the `headless: ENV['MAGIC_TEST'] ? false : …` switch | `spec/unit/cuprite_defaults_spec.rb` | `ActionDispatch::SystemTesting::Driver#register` (actionpack 7.0.8). The gem now forces a headed 1200×800 window itself under `MAGIC_TEST`. |

## Unmerged branches

### `origin/chosen-js-support` (2 commits)

Already an ancestor of `semantic-selector-improvements` (`git merge-base --is-ancestor` is true), so there is nothing new to merge. Evaluation of its ideas:

* **Lifted:** mapping a Chosen container back to its `<select>` through the `<id>_chosen` convention, and treating containers of selects without an id as unstable.
* **Rejected:** emitting `open`/`search`/`select`/`deselect` as four separate events and folding them later in Ruby with a backwards lookahead (source of bug #10), and locating the widget by `find('#<id>_chosen')`. The rewrite folds the search into the pick in JS and emits `magic_chosen_select('Fest', from: 'Kategori')`, which finds the underlying select by label/id/name (`visible: false`) and does not need an id.

### `origin/hover-feature` (15 commits)

* **Lifted (as ideas, re-implemented):** (1) "a hover only matters when it visibly changed something" — the rewrite records hover only as an explicit toolbar action and uses the `aria-expanded` / `.show` transition check from this branch to colour the step green (visible effect) or amber (nothing opened); (2) capture-phase `addEventListener(..., true)` registration; (3) the Ruby side did emit `within(...) do … end` for scoped events (the only place bug #1 was ever fixed) — the intent is kept, the implementation is not (no merging of consecutive steps, `puts` debug noise, and the scope selector was still a pre-built Ruby string).
* **Rejected:** an always-on `mouseover` listener with a 400 ms timer plus `requestAnimationFrame` and a `MutationObserver` on `document.body` (bug #18/#19, costs a DOM walk per mouse move); `selectorResult.type !== 'error'` — `findBestSelector` never returns `'error'`, so a scoped result emits `find('undefined').hover`; registering click/keypress listeners a second time in capture phase while `_listeners.html` still registers them in bubble phase (each click handled twice, hidden by the debounce); more `console.log` per event.

## Status after the rewrite

See the bottom of this file once the rewrite is complete: every regression test above passes against the new recorder (`bin/rspec spec/audit`).
