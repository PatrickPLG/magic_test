// The floating toolbar: a draggable, collapsible panel in a Shadow DOM root
// (app CSS cannot touch it, and events inside it are never recorded).
MT.toolbar = (function () {
  var host = null, root = null, els = {}, state = null, collapsed = false, notice = null, dialog = null;
  var CSS = [
    ':host { all: initial; }',
    '.mt { position: fixed; top: 12px; right: 12px; width: 420px; max-height: 76vh; z-index: 2147483000; font: 12px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; color: #1c1f23; background: #fff; border: 1px solid #c9ced6; border-radius: 8px; box-shadow: 0 8px 28px rgba(0,0,0,.22); display: flex; flex-direction: column; overflow: hidden; }',
    '.mt.collapsed .body, .mt.collapsed .foot { display: none; }',
    '.mt.collapsed { width: auto; }',
    '.head { display: flex; align-items: center; gap: 8px; padding: 8px 10px; background: #1f2937; color: #fff; cursor: move; user-select: none; }',
    '.head .title { font-weight: 600; flex: 1; white-space: nowrap; }',
    '.head .status { font-size: 11px; padding: 2px 8px; border-radius: 10px; background: #dc2626; }',
    '.head .status.paused { background: #6b7280; } .head .status.finished { background: #2563eb; }',
    '.head button, .foot button, .bar button { font: inherit; padding: 3px 8px; border-radius: 4px; border: 1px solid #9aa3af; background: #f3f4f6; color: #111; cursor: pointer; }',
    '.head button { background: transparent; color: #fff; border-color: #6b7280; }',
    '.bar { display: flex; flex-wrap: wrap; gap: 6px; padding: 6px 10px; border-bottom: 1px solid #e5e7eb; background: #f9fafb; }',
    '.bar button.on { background: #fde68a; border-color: #d97706; }',
    '.body { overflow: auto; flex: 1; padding: 6px 10px; }',
    '.foot { display: flex; gap: 6px; padding: 8px 10px; border-top: 1px solid #e5e7eb; background: #f9fafb; flex-wrap: wrap; }',
    '.foot .primary { background: #2563eb; color: #fff; border-color: #1d4ed8; }',
    '.step { display: grid; grid-template-columns: 14px 1fr auto; gap: 6px; align-items: start; padding: 4px 0; border-bottom: 1px dashed #e5e7eb; }',
    '.step.saved { opacity: .55; }',
    '.badge { width: 10px; height: 10px; border-radius: 50%; margin-top: 4px; }',
    '.badge.green { background: #16a34a; } .badge.amber { background: #d97706; } .badge.red { background: #dc2626; }',
    '.code { font: 11px/1.45 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; white-space: pre-wrap; word-break: break-word; }',
    '.review { color: #b45309; font-size: 11px; }',
    '.actions { display: flex; gap: 3px; }',
    '.actions button, .sugg button { font: inherit; font-size: 11px; padding: 1px 5px; border-radius: 3px; border: 1px solid #c9ced6; background: #fff; cursor: pointer; }',
    'h4 { margin: 8px 0 4px; font-size: 11px; text-transform: uppercase; letter-spacing: .04em; color: #6b7280; }',
    '.sugg { display: flex; gap: 6px; align-items: start; padding: 3px 0; }',
    '.setup { background: #fef3c7; border: 1px solid #fcd34d; border-radius: 4px; padding: 6px; margin: 4px 0; }',
    '.notice { padding: 6px 10px; background: #ecfdf5; color: #065f46; border-bottom: 1px solid #a7f3d0; }',
    '.notice.error { background: #fef2f2; color: #991b1b; border-color: #fecaca; }',
    '.dialog { position: fixed; left: 50%; top: 18%; transform: translateX(-50%); width: 440px; background: #fff; border: 2px solid #dc2626; border-radius: 8px; padding: 14px; box-shadow: 0 12px 40px rgba(0,0,0,.35); z-index: 2147483001; font: 13px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; color: #111; }',
    '.dialog h3 { margin: 0 0 6px; font-size: 14px; } .dialog .msg { white-space: pre-wrap; margin-bottom: 10px; } .dialog input { width: 100%; box-sizing: border-box; margin-bottom: 8px; padding: 4px 6px; font: inherit; }',
    '.dialog .btns { display: flex; gap: 8px; justify-content: flex-end; } .dialog button { font: inherit; padding: 4px 12px; border-radius: 4px; border: 1px solid #9aa3af; background: #f3f4f6; cursor: pointer; } .dialog button.accept { background: #2563eb; color: #fff; border-color: #1d4ed8; }',
    'select.alt { font: inherit; font-size: 11px; max-width: 200px; }',
    '.empty { color: #6b7280; padding: 10px 0; }',
    '.kbd { font: 10px ui-monospace, monospace; background: #e5e7eb; border-radius: 3px; padding: 0 4px; color: #374151; }',
    'button.hint { width: 15px; height: 15px; padding: 0; line-height: 13px; border-radius: 50%; font-size: 10px; border: 1px solid #9aa3af; background: #fff; color: #374151; cursor: pointer; vertical-align: middle; }',
    'button.hint:hover, button.hint:focus { background: #2563eb; color: #fff; border-color: #2563eb; outline: none; }',
    '.badge { cursor: pointer; border: 0; padding: 0; }',
    '.popover { position: fixed; z-index: 2147483002; max-width: 380px; background: #111827; color: #e5e7eb; border-radius: 6px; padding: 8px 10px; font-size: 12px; box-shadow: 0 6px 20px rgba(0,0,0,.3); }',
    '.popover .when { color: #9ca3af; margin-top: 4px; }',
    '.popover pre { margin: 6px 0 0; font: 11px/1.4 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; background: #0f172a; padding: 6px; border-radius: 4px; white-space: pre-wrap; color: #e2e8f0; }',
    '.popover h5 { margin: 0 0 4px; font-size: 12px; } .popover ul { margin: 4px 0 0; padding-left: 16px; } .popover li { margin: 2px 0; } .popover .why { color: #9ca3af; }'
  ].join('\n');

  function h(tag, attrs, children) {
    var el = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (k) {
      if (k === 'class') el.className = attrs[k];
      else if (k === 'text') el.textContent = attrs[k];
      else if (k === 'html') el.innerHTML = attrs[k];
      else if (k.indexOf('on') === 0) el.addEventListener(k.slice(2), attrs[k]);
      else el.setAttribute(k, attrs[k]);
    });
    (children || []).forEach(function (c) { if (c) el.appendChild(typeof c === 'string' ? document.createTextNode(c) : c); });
    return el;
  }

  // ---- "?" hints (1.2 §6) from config/hints.yml (MT.config.hints), one popover at a time.
  var popover = null;
  function hintData(key) { return ((MT.config && MT.config.hints) || {})[key]; }
  function closePopover() { if (popover) { popover.node.remove(); popover.anchor.removeAttribute('aria-describedby'); popover = null; } }
  function openPopover(anchor, children) {
    closePopover();
    var id = 'mt-hint-' + Math.random().toString(36).slice(2, 8);
    var node = h('div', { class: 'popover', role: 'tooltip', id: id }, children);
    root.appendChild(node);
    var r = anchor.getBoundingClientRect();
    var left = Math.max(6, Math.min(r.left, window.innerWidth - 400));
    var top = r.bottom + 6;
    node.style.left = left + 'px';
    node.style.top = top + 'px';
    if (top + node.offsetHeight > window.innerHeight) node.style.top = Math.max(6, r.top - node.offsetHeight - 6) + 'px';
    anchor.setAttribute('aria-describedby', id);
    popover = { node: node, anchor: anchor };
  }
  function hintChildren(key) {
    var d = hintData(key);
    if (!d) return [h('div', { text: 'No hint for ' + key })];
    return [h('div', { text: d.text }), d.when ? h('div', { class: 'when', text: 'When: ' + d.when }) : null, d.example ? h('pre', { text: String(d.example).replace(/\s+$/, '') }) : null];
  }
  // The "?" button for a hint key such as 'have_content' (toolbar section).
  function hint(key, label) {
    var btn = h('button', { type: 'button', class: 'hint', 'data-hint': 'toolbar.' + key, 'aria-label': label || ('What is ' + key.replace(/_/g, ' ') + '?'), text: '?' });
    btn.addEventListener('mouseenter', function () { openPopover(btn, hintChildren(key)); });
    btn.addEventListener('focus', function () { openPopover(btn, hintChildren(key)); });
    btn.addEventListener('mouseleave', function () { if (root.activeElement !== btn) closePopover(); });
    btn.addEventListener('blur', closePopover);
    btn.addEventListener('click', function (e) { e.preventDefault(); e.stopPropagation(); if (popover && popover.anchor === btn) closePopover(); else openPopover(btn, hintChildren(key)); });
    return btn;
  }
  var ASSERTION_HINTS = { '': 'have_css', css: 'have_css', no_css: 'have_no_css', field: 'have_field', checked: 'have_checked_field', unchecked: 'have_checked_field', select: 'have_select', button: 'have_button', link: 'have_link', count: 'have_css' };
  var SUGGESTION_HINTS = { flash: 'have_content', toast: 'toast', modal_closed: 'modal_closed', db_count: 'change_count', db_attr: 'reload_attr', path: 'have_current_path', mail: 'have_content', job: 'change_count', content: 'have_content', no_content: 'have_no_content' };
  function suggestionHintKey(s) {
    if (SUGGESTION_HINTS[s.kind]) return SUGGESTION_HINTS[s.kind];
    var m = /have_(no_content|content|css|no_css|field|checked_field|unchecked_field|select|button|link|current_path)/.exec(s.code || '');
    return m ? (m[1] === 'unchecked_field' ? 'have_checked_field' : 'have_' + m[1]) : 'have_content';
  }
  // "Why this locator?": the chosen code and every alternative with the reason it lost.
  function whyLost(step, c) {
    var cand = c.candidate || {};
    if (cand.kind === 'positional') return 'positional selectors are the last resort';
    if (cand.scope) return 'needs a within(' + cand.scope.css + ') scope; a global locator ranks higher';
    if (cand.kind === 'css') return 'CSS ranks below labels, text, ids and names';
    if (cand.by === 'own_text' || cand.by === 'text') return 'text ranks below a label; several texts tie by order';
    return 'ranks lower than the chosen ' + (step.locator ? 'text' : 'locator');
  }
  function whyLocator(step) {
    var alts = (step.candidates || []).filter(function (c) { return c.code !== step.code; });
    return [
      h('h5', { text: 'Why this locator?' }),
      h('div', { class: 'code', text: step.code || '' }),
      h('div', { class: 'why', text: step.confidence === 'green' ? 'A verified unique semantic locator (label, text, id or name): the recorder\'s first choice.' : (step.confidence === 'amber' ? 'Unique only inside a scope, or a CSS selector: fine, but a stable id or text would be better.' : 'Not unique or not stable: review it before saving.') }),
      alts.length ? h('ul', {}, alts.slice(0, 6).map(function (c) { return h('li', {}, [h('span', { class: 'code', text: c.code }), h('div', { class: 'why', text: c.label + ' — ' + whyLost(step, c) })]); })) : h('div', { class: 'why', text: 'No other unique candidate.' }),
      h('div', { class: 'when', text: hintData('why_locator') ? hintData('why_locator').text : '' })
    ];
  }

  function mount() {
    if (host || !document.body) return;
    if (MT.windows.isChildWindow() === false && window.top !== window) return; // no toolbar inside iframes
    host = document.createElement('div');
    host.setAttribute('data-magic-test', 'toolbar');
    root = host.attachShadow({ mode: 'open' });
    root.appendChild(h('style', { text: CSS }));
    var panel = h('div', { class: 'mt' });
    els.panel = panel;
    els.status = h('span', { class: 'status', text: 'REC' });
    // Re-render on every state poll and status change, so the step list is
    // live without the person touching the panel.
    MT.transport.onState(function () { render(); });
    MT.session.onStatus(function () { render(); });
    els.collapse = h('button', { text: '–', title: 'Collapse', onclick: function () { collapsed = !collapsed; panel.classList.toggle('collapsed', collapsed); els.collapse.textContent = collapsed ? '+' : '–'; } });
    var head = h('div', { class: 'head' }, [h('span', { class: 'title', text: 'magic_test' }), els.status, els.collapse]);
    makeDraggable(head, panel);
    els.notice = h('div', { class: 'notice', style: 'display:none' });
    els.recordBtn = h('button', { text: 'Pause', title: 'Alt+Shift+R', onclick: toggleRecording });
    els.assertBtn = h('button', { text: 'Assert: click element', title: 'Alt+Shift+A', onclick: function () { MT.modes.set(MT.modes.current() === 'assert' ? 'record' : 'assert', { assertion_type: els.assertType.value || null }); render(); } });
    els.assertType = h('select', { class: 'alt', title: 'Assertion type for the next click' }, [
      opt('', 'auto'), opt('css', 'have_css'), opt('no_css', 'have_no_css'), opt('field', 'have_field'), opt('checked', 'have_checked_field'), opt('unchecked', 'have_unchecked_field'),
      opt('select', 'have_select'), opt('button', 'have_button'), opt('link', 'have_link'), opt('count', 'count in list/table')
    ]);
    els.assertHint = hint(ASSERTION_HINTS[''], 'What does this assertion check?');
    els.assertHint.setAttribute('data-hint-for', 'assertion-type');
    els.assertType.addEventListener('change', function () { els.assertHint.setAttribute('data-hint', 'toolbar.' + ASSERTION_HINTS[els.assertType.value]); });
    els.assertHint.addEventListener('mouseenter', function () { openPopover(els.assertHint, hintChildren(ASSERTION_HINTS[els.assertType.value] || 'have_css')); });
    els.assertHint.addEventListener('focus', function () { openPopover(els.assertHint, hintChildren(ASSERTION_HINTS[els.assertType.value] || 'have_css')); });
    els.selectionBtn = h('button', { text: 'Assert selection', title: 'Alt+Shift+X: highlighted text → have_content', onclick: function () { MT.assert.fromSelection(false); } });
    els.noSelectionBtn = h('button', { text: 'Assert absent', title: 'have_no_content for the highlighted text', onclick: function () { MT.assert.fromSelection(true); } });
    els.pathBtn = h('button', { text: 'Assert path', onclick: function () { MT.assert.currentPath(); } });
    els.hoverBtn = h('button', { text: 'Hover next', title: 'Record a hover on the next element you click (or Alt+Shift+H with the mouse over it)', onclick: function () { MT.modes.set(MT.modes.current() === 'hover' ? 'record' : 'hover'); render(); } });
    els.i18nBtn = h('button', { text: 'I18n keys', title: 'Toggle I18n.t(...) vs literal text', onclick: function () { MT.transport.command('toggle_i18n').then(render); } });
    var bar = h('div', { class: 'bar' }, [els.recordBtn, els.assertBtn, els.assertType, els.assertHint, els.selectionBtn, hint('have_content', 'What does Assert selection write?'), els.noSelectionBtn, hint('have_no_content', 'Why have_no_content beats not_to have_content'), els.pathBtn, hint('have_current_path', 'What does Assert path write?'), els.hoverBtn, els.i18nBtn]);
    els.body = h('div', { class: 'body' });
    els.saveBtn = h('button', { class: 'primary', text: 'Save', title: 'Alt+Shift+S', onclick: function () { command('save'); } });
    els.finishBtn = h('button', { class: 'primary', text: 'Save & finish', onclick: function () { command('save_and_finish'); } });
    els.replayBtn = h('button', { text: 'Replay pending', title: 'Check every pending locator against the live page', onclick: function () { command('replay_pending'); } });
    els.discardBtn = h('button', { text: 'Discard', onclick: function () { if (MT.dialogs.original.confirm.call(window, 'Discard all pending steps?')) command('discard'); } });
    els.consoleBtn = h('button', { text: 'Console', title: 'Open a Pry console in the terminal (flush / ok)', onclick: function () { command('open_console'); } });
    var foot = h('div', { class: 'foot' }, [els.saveBtn, els.finishBtn, els.replayBtn, els.discardBtn, els.consoleBtn]);
    panel.appendChild(head); panel.appendChild(els.notice); panel.appendChild(bar); panel.appendChild(els.body); panel.appendChild(foot);
    root.appendChild(panel);
    document.body.appendChild(host);
    MT.modes.onChange(render);
    render();
    if (dialog) showDialog(dialog);
  }

  function opt(value, label) { return h('option', { value: value, text: label }); }

  function makeDraggable(handle, panel) {
    var startX, startY, startLeft, startTop, dragging = false;
    handle.addEventListener('mousedown', function (e) {
      if (e.target.tagName === 'BUTTON') return;
      dragging = true; startX = e.clientX; startY = e.clientY;
      var rect = panel.getBoundingClientRect(); startLeft = rect.left; startTop = rect.top;
      panel.style.right = 'auto'; panel.style.left = startLeft + 'px'; panel.style.top = startTop + 'px';
      e.preventDefault();
    });
    window.addEventListener('mousemove', function (e) {
      if (!dragging) return;
      panel.style.left = Math.max(0, startLeft + e.clientX - startX) + 'px';
      panel.style.top = Math.max(0, startTop + e.clientY - startY) + 'px';
    }, true);
    window.addEventListener('mouseup', function () { dragging = false; }, true);
  }

  function toggleRecording() {
    var paused = MT.recording.paused();
    if (paused) { MT.recording.resume(); MT.transport.command('resume').then(render); } else { MT.recording.pause(); MT.transport.command('pause').then(render); }
    render();
  }

  var SAVE_LIKE = { save: true, save_and_finish: true, replay_pending: true, open_console: true };

  // A value still being typed is committed and delivered before the server
  // builds the steps, so "type, then click Save" never loses the fill.
  function drained() {
    return new Promise(function (resolve) {
      var deadline = Date.now() + 3000;
      (function tick() {
        if (!MT.transport.pending() || Date.now() > deadline) return resolve();
        MT.transport.flush();
        setTimeout(tick, 50);
      })();
    });
  }

  function command(name, params) {
    var ready = Promise.resolve();
    if (SAVE_LIKE[name]) { MT.typing.commitAll(name); ready = drained(); }
    return ready.then(function () { return MT.transport.command(name, params); }).then(function (res) {
      if (res && res.ok === false) notify(res.error || 'failed', true);
      else if (res && res.message) notify(res.message);
      if (name === 'replay_pending' && res && res.replay) {
        var bad = Object.keys(res.replay).filter(function (k) { return res.replay[k].ok === false; });
        notify(bad.length ? bad.length + ' step(s) do not resolve' : 'All pending locators resolve', bad.length > 0);
      }
      render();
      return res;
    }).catch(function (e) { notify(String(e), true); });
  }

  function notify(text, isError) {
    notice = { text: text, error: !!isError, at: Date.now() };
    render();
    setTimeout(function () { if (notice && Date.now() - notice.at >= 3900) { notice = null; render(); } }, 4000);
  }

  function render() {
    if (!host) return;
    state = MT.transport.lastState() || state;
    var status = MT.session.status();
    var paused = MT.recording.paused();
    els.status.textContent = paused ? 'PAUSED' : (status === 'recording' ? 'REC' : status.toUpperCase());
    els.status.className = 'status' + (paused ? ' paused' : (status === 'finished' ? ' finished' : ''));
    els.recordBtn.textContent = paused ? 'Record' : 'Pause';
    els.assertBtn.classList.toggle('on', MT.modes.current() === 'assert');
    els.hoverBtn.classList.toggle('on', MT.modes.current() === 'hover');
    els.i18nBtn.classList.toggle('on', !!(state && state.i18n_keys));
    els.notice.style.display = notice ? '' : 'none';
    els.notice.className = 'notice' + (notice && notice.error ? ' error' : '');
    els.notice.textContent = notice ? notice.text : '';
    var body = els.body;
    body.innerHTML = '';
    if (!state) { body.appendChild(h('div', { class: 'empty', text: 'Connecting to the recording session…' })); return; }
    var steps = state.steps || [];
    var saved = state.saved_count || 0;
    body.appendChild(h('h4', {}, ['Steps (' + (steps.length - saved) + ' pending, ' + saved + ' saved) ', hint('confidence', 'What do the coloured badges mean?')]));
    if (!steps.length) body.appendChild(h('div', { class: 'empty', text: 'Click around the app. Every step shows here as the exact Ruby line it will produce.' }));
    steps.forEach(function (step, i) {
      var isSaved = i < saved;
      var replay = state.replay && state.replay[step.id];
      var badge = h('button', { type: 'button', class: 'badge ' + step.confidence, 'data-why': step.id, 'aria-label': 'Why this locator?', title: (step.confidence === 'green' ? 'Unique semantic locator (verified)' : (step.confidence === 'amber' ? 'Scoped or CSS locator' : 'Needs review')) + ' — click: why this locator?' });
      badge.addEventListener('click', function (e) { e.preventDefault(); e.stopPropagation(); if (popover && popover.anchor === badge) closePopover(); else openPopover(badge, whyLocator(step)); });
      var row = h('div', { class: 'step' + (isSaved ? ' saved' : '') }, [
        badge,
        h('div', {}, [
          h('div', { class: 'code', text: step.code || '(nothing)' }),
          step.review ? h('div', { class: 'review' }, ['⚠ ' + step.review + ' ', hint('review_comment', 'What is a REVIEW comment?')]) : null,
          replay ? h('div', { class: 'review', text: replay.ok === false ? '✗ does not resolve (' + (replay.error || ('found ' + replay.found)) + ')' : (replay.ok ? '✓ resolves' : '– ' + (replay.note || '')) }) : null
        ]),
        isSaved ? h('span') : h('div', { class: 'actions' }, [
          step.candidates && step.candidates.length > 1 ? altSelect(step) : null,
          step.locator ? h('button', { text: step.i18n ? 'literal' : 'I18n', title: 'Toggle I18n key vs literal text for this step', onclick: function () { MT.transport.command('set_locator', { step_id: step.id, i18n: !step.i18n }).then(render); } }) : null,
          h('button', { text: '×', title: 'Delete step', onclick: function () { MT.transport.command('delete_step', { step_id: step.id }).then(render); } })
        ])
      ]);
      body.appendChild(row);
    });
    var sugg = state.suggestions || [];
    if (sugg.length) {
      body.appendChild(h('h4', { text: 'Suggested assertions' }));
      sugg.forEach(function (s) {
        body.appendChild(h('div', { class: 'sugg' }, [
          h('button', { text: '+', title: 'Add this assertion as a step', onclick: function () { MT.transport.command('accept_suggestion', { suggestion_id: s.id }).then(render); } }),
          s.candidates && s.candidates.length ? h('button', { text: '+block', title: 'Add the expect { } block form instead', onclick: function () { MT.transport.command('accept_suggestion', { suggestion_id: s.id, alternative: s.candidates[0].code }).then(render); } }) : null,
          h('div', { class: 'code' }, [s.code + ' ', hint(suggestionHintKey(s), 'What does this assertion check?')])
        ]));
      });
    }
    var setup = state.setup || [];
    if (setup.length) {
      body.appendChild(h('h4', { text: 'Setup for the next run (copy by hand)' }));
      setup.forEach(function (s) {
        body.appendChild(h('div', { class: 'setup' }, [h('div', { class: 'code', text: s.code }), s.alt ? h('div', { class: 'code', text: 'or: ' + s.alt }) : null, h('div', { class: 'review', text: s.note || '' })]));
      });
    }
    if (state.messages && state.messages.length) {
      body.appendChild(h('h4', { text: 'Log' }));
      state.messages.slice(-3).forEach(function (m) { body.appendChild(h('div', { class: 'review', text: m })); });
    }
    body.appendChild(h('div', { class: 'empty', html: 'Shortcuts: <span class="kbd">Alt+Shift+R</span> pause · <span class="kbd">Alt+Shift+A</span> assert mode · <span class="kbd">Alt+Shift+X</span> assert selection · <span class="kbd">Alt+Shift+H</span> hover · <span class="kbd">Alt+Shift+S</span> save' }));
  }

  function altSelect(step) {
    var sel = h('select', { class: 'alt', title: 'Choose another locator' });
    sel.appendChild(opt('', 'locator…'));
    step.candidates.forEach(function (c, i) { sel.appendChild(opt(String(i), c.label + ': ' + c.code)); });
    sel.addEventListener('change', function () {
      var c = step.candidates[parseInt(sel.value, 10)];
      if (!c) return;
      MT.transport.command('set_locator', { step_id: step.id, locator: c.candidate ? c.candidate.locator : null, code: c.candidate ? null : c.code }).then(render);
    });
    return sel;
  }

  function showDialog(p) {
    dialog = p;
    if (!root) return;
    hideDialog(true);
    var input = p.type === 'prompt' ? h('input', { type: 'text', value: p.defaultValue || '' }) : null;
    var box = h('div', { class: 'dialog' }, [
      h('h3', { text: p.type === 'alert' ? 'The app showed an alert' : (p.type === 'prompt' ? 'The app asks for input' : 'The app asks for confirmation') }),
      h('div', { class: 'msg', text: p.message }),
      input,
      h('div', { class: 'btns' }, p.type === 'alert' ? [h('button', { class: 'accept', text: 'OK', onclick: function () { hideDialog(); } })] : [
        h('button', { text: p.type === 'prompt' ? 'Cancel (dismiss_prompt)' : 'Cancel (dismiss_confirm)', onclick: function () { MT.dialogs.answer(false); } }),
        h('button', { class: 'accept', text: p.type === 'prompt' ? 'OK (accept_prompt)' : 'OK (accept_confirm)', onclick: function () { MT.dialogs.answer(true, input ? input.value : undefined); } })
      ])
    ]);
    box.setAttribute('data-mt-dialog', '1');
    root.appendChild(box);
    els.dialog = box;
  }

  function hideDialog(keep) {
    if (els.dialog) { els.dialog.remove(); els.dialog = null; }
    if (!keep) dialog = null;
  }

  // Moves the panel to the other side of the viewport when it covers the
  // given point (what a person does by dragging it out of the way). Returns
  // true when the point was covered.
  function dodge(x, y) {
    if (!host || !els.panel) return false;
    var el = document.elementFromPoint(x, y);
    if (!el || (el !== host && !host.contains(el))) return false;
    var onRight = x > window.innerWidth / 2;
    els.panel.style.left = onRight ? '12px' : 'auto';
    els.panel.style.right = onRight ? 'auto' : '12px';
    return true;
  }

  // Alt+Shift+<key> avoids Chrome's and Studiz's shortcuts.
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closePopover(); }, true);

  function shortcut(e) {
    if (!e.altKey || !e.shiftKey || e.ctrlKey || e.metaKey) return false;
    var key = (e.code || '').replace('Key', '').toLowerCase() || (e.key || '').toLowerCase();
    var handled = true;
    switch (key) {
      case 'r': toggleRecording(); break;
      case 'a': MT.modes.set(MT.modes.current() === 'assert' ? 'record' : 'assert', {}); render(); break;
      case 'x': MT.assert.fromSelection(false); break;
      case 'h': MT.hover.recordAtPointer(); break;
      case 's': command('save'); break;
      default: handled = false;
    }
    if (handled) { e.preventDefault(); e.stopPropagation(); }
    return handled;
  }

  return { mount: mount, render: render, notify: notify, dodge: dodge, showDialog: showDialog, hideDialog: hideDialog, shortcut: shortcut, host: function () { return host; } };
})();
