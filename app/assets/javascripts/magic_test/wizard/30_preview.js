// The pinned right column (skeleton, issues, chips, preflight result), the
// footer navigation (Back / Next / Run preflight / Start recording / Cancel)
// and, after Start, the status screen of the recording (B9).
W.preview = (function () {
  var h = W.h;
  var S = W.state;
  var els = {};

  function bind() {
    els.preview = document.getElementById('preview');
    els.issues = document.getElementById('issues');
    els.notice = document.getElementById('notice');
    els.status = document.getElementById('status');
    els.path = document.getElementById('path');
    els.result = document.getElementById('preflight-result');
    els.back = document.getElementById('back');
    els.next = document.getElementById('next');
    els.preflightBtn = document.getElementById('preflight');
    els.startBtn = document.getElementById('start');
    els.cancelBtn = document.getElementById('cancel');
    els.back.addEventListener('click', function () { W.steps.back(); });
    els.next.addEventListener('click', function () { W.steps.next(); });
    els.preflightBtn.addEventListener('click', runPreflight);
    els.startBtn.addEventListener('click', start);
    els.cancelBtn.addEventListener('click', function () { if (window.confirm('Cancel the wizard? Nothing has been written.')) W.api.post('cancel', {}).then(function () { notice('Cancelled. Nothing was written; you can close this window.', true); }); });
  }

  var schedule = W.util.debounce(function () { refresh(); }, 250);

  function refresh() {
    return W.api.post('preview', { plan: S.plan }).then(function (res) {
      S.preview = res;
      S.issues = res.issues || [];
      var hadBlocks = !!document.getElementById('w-block');
      S.blocks = res.blocks || [];
      adoptWiring(res.plan);
      render();
      var wantBlocks = !!(res.file_exists && S.blocks.length && S.targetExisting);
      if (S.step === 1 && wantBlocks !== hadBlocks) W.steps.render();
      if (S.step === 4) W.steps.render();
      return res;
    });
  }

  // The server auto-wires associations; keep what it decided for the ones we left empty.
  function adoptWiring(plan) {
    if (!plan || !plan.models) return;
    plan.models.forEach(function (sm) {
      var local = S.plan.models.filter(function (m) { return m.let === sm.let; })[0];
      if (!local) return;
      Object.keys(sm.associations || {}).forEach(function (k) { if (!local.associations[k]) local.associations[k] = sm.associations[k]; });
    });
  }

  // The skeleton; for an existing file the inserted lines are highlighted.
  function renderCode(res) {
    els.preview.innerHTML = '';
    var sk = res.skeleton;
    if (!sk || !sk.source) { els.preview.textContent = res.ok === false ? '# fix the issues to see the skeleton' : '…'; return; }
    if (!res.file_exists || !sk.insert_before_line || !sk.body_lines) { els.preview.textContent = sk.source; return; }
    var lines = sk.source.split('\n');
    var start = sk.insert_before_line - 1; // 0-based index where the insertion begins
    var inserted = sk.body_lines.length + 1; // insertion_for adds a blank line before the body
    lines.forEach(function (line, i) {
      var cls = (i >= start && i < start + inserted) ? 'ins' : 'ctx';
      els.preview.appendChild(h('span', { class: cls, text: line }));
    });
  }

  function render() {
    var res = S.preview || {};
    renderCode(res);
    els.path.textContent = res.path ? (res.skeleton ? res.skeleton.mode.replace('_', ' ') + ' → ' : '') + res.path : '';
    renderChips();
    els.issues.innerHTML = '';
    document.querySelectorAll('.field-error').forEach(function (n) { n.remove(); });
    // Errors only for fields the person touched or steps where Next was pressed
    // (B6: warnings and hints fold into a <details>).
    var folded = [];
    var shownErrors = 0;
    S.issues.forEach(function (issue) {
      var row = h('div', { class: 'issue ' + issue.severity }, [h('strong', { text: issue.field + ': ' }), issue.message, issue.fix ? h('span', { class: 'fix', text: (issue.severity === 'hint' ? '' : 'fix: ') + issue.fix }) : null]);
      if (issue.data && issue.data.add_model) {
        row.appendChild(h('button', { type: 'button', text: 'add let!(:' + issue.data.add_model.let + ')', onclick: function () {
          S.plan.models.push(W.util.newModel(issue.data.add_model.factory, issue.data.add_model.let));
          W.steps.render(); schedule();
        } }));
      }
      if (issue.severity === 'error') {
        if (!W.util.showsErrorFor(issue.field) && S.step !== 4) return;
        shownErrors += 1;
        els.issues.appendChild(row);
        var target = document.querySelector('[data-field="' + issue.field + '"]');
        if (target) target.appendChild(h('div', { class: 'field-error', text: issue.message }));
      } else {
        folded.push(row);
      }
    });
    if (folded.length) {
      var warnings = S.issues.filter(function (i) { return i.severity === 'warning'; }).length;
      var hints = folded.length - warnings;
      var summary = [warnings ? warnings + (warnings === 1 ? ' warning' : ' warnings') : null, hints ? hints + (hints === 1 ? ' hint' : ' hints') : null].filter(Boolean).join(' · ');
      els.issues.appendChild(h('details', { id: 'warnings', class: 'warnings' }, [h('summary', { text: summary })].concat(folded)));
    }
    renderNav();
    setStatus(S.status, S.status === 'planning' && shownErrors ? 'err' : (S.status === 'preflighted' ? 'ok' : ''));
  }

  // One primary action per step: Next on 1-3; Run preflight on 4, then Start.
  function renderNav() {
    if (!els.next) return;
    var errors = W.steps.stepErrors(S.step).length;
    var last = S.step === 4;
    els.back.disabled = S.step === 1 || S.status === 'recording';
    els.next.classList.toggle('hidden', last);
    els.next.disabled = S.status === 'recording';
    els.next.textContent = errors && S.nextPressed[S.step] ? 'Fix the ' + errors + (errors === 1 ? ' issue to continue' : ' issues to continue') : 'Next';
    var res = S.preview || {};
    var changedSincePreflight = !S.preflightedPlan || JSON.stringify(S.preflightedPlan) !== JSON.stringify(S.plan);
    var canStart = !!(S.preflight && S.preflight.ok && !changedSincePreflight && S.status === 'preflighted');
    els.preflightBtn.classList.toggle('hidden', !last);
    els.preflightBtn.classList.toggle('primary', !canStart);
    els.preflightBtn.disabled = !(res.ok && S.status !== 'preflighting' && S.status !== 'recording');
    els.startBtn.classList.toggle('hidden', !last || !canStart);
    els.startBtn.disabled = !canStart;
  }

  // B5: one removable chip per chosen trait ("provider :with_cvr ×").
  function renderChips() {
    var box = document.getElementById('chips');
    if (!box) return;
    box.innerHTML = '';
    S.plan.models.forEach(function (m) {
      (m.traits || []).forEach(function (t) {
        box.appendChild(h('span', { class: 'chip', 'data-let': m.let, 'data-trait': t }, [
          m.let + ' :' + t,
          h('button', { type: 'button', class: 'chip-remove', 'aria-label': 'remove :' + t + ' from ' + m.let, title: 'remove :' + t, text: '×', onclick: function () {
            m.traits = m.traits.filter(function (x) { return x !== t; });
            W.steps.render();
            schedule();
          } })
        ]));
      });
    });
  }

  function setStatus(text, cls) {
    els.status.textContent = text;
    els.status.className = 'status ' + (cls || '');
  }

  function notice(text, error) {
    els.notice.textContent = text;
    els.notice.className = 'notice' + (error ? ' error' : '');
    els.notice.classList.toggle('hidden', !text);
  }

  function runPreflight() {
    S.status = 'preflighting';
    S.preflight = null;
    render();
    els.result.innerHTML = '';
    els.result.appendChild(h('p', { class: 'muted', text: 'Running the setup, signing in and visiting the start page in a second window…' }));
    var plan = JSON.parse(JSON.stringify(S.plan));
    W.api.post('preflight', { plan: plan }).then(function (res) {
      S.preflight = res.preflight || { ok: false, failures: [{ stage: 'server', message: res.error || 'preflight failed', fix: null }] };
      S.preflightedPlan = res.ok ? plan : null;
      S.status = res.ok ? 'preflighted' : 'planning';
      if (res.issues && res.issues.length) S.issues = res.issues;
      if (S.source && S.source.indexOf('starter:') === 0) refreshStarterStatus(S.source.slice(8), res.ok, S.preflight);
      renderPreflight();
      render();
    }).catch(function (e) { S.status = 'planning'; notice('preflight request failed: ' + e, true); render(); });
  }

  // The starter card's status follows the preflight (the server persists it).
  function refreshStarterStatus(id, ok, preflight) {
    (S.catalogue.starters || []).forEach(function (st) {
      if (st.id !== id) return;
      st.ok = ok; st.verified_at = new Date().toISOString();
      st.message = ok ? null : (preflight.failures && preflight.failures[0] ? preflight.failures[0].stage + ': ' + preflight.failures[0].message : 'failed');
    });
  }

  function renderPreflight() {
    var p = S.preflight;
    els.result.innerHTML = '';
    if (!p) return;
    if (p.ok) {
      els.result.appendChild(h('div', { class: 'ok', id: 'preflight-ok', text: '✓ Preflight passed: ' + p.status + ' ' + p.path + (p.title ? ' — ' + p.title : '') }));
      els.result.appendChild(h('div', { class: 'muted', text: 'Signed in as ' + (p.user || 'guest') + ' · ' + (p.records || []).map(function (r) { return r.let + ' = ' + r.class + '#' + r.id; }).join(', ') }));
      (p.warnings || []).forEach(function (w) {
        els.result.appendChild(h('div', { class: 'issue warning' }, [h('strong', { text: w.stage + ': ' }), w.message, w.fix ? h('span', { class: 'fix', text: ' ' + w.fix }) : null]));
      });
      (p.notes || []).forEach(function (n) { els.result.appendChild(h('div', { class: 'muted', text: 'note: ' + n })); });
    } else {
      els.result.appendChild(h('div', { class: 'fail', id: 'preflight-failed', text: '✗ Preflight failed' }));
      (p.failures || []).forEach(function (f) {
        els.result.appendChild(h('div', { class: 'issue error' }, [h('strong', { text: f.stage + ': ' }), f.message, f.fix ? h('span', { class: 'fix', text: 'fix: ' + f.fix }) : null]));
      });
      if (S.source && S.source.indexOf('starter:') === 0) els.result.appendChild(h('div', { class: 'issue warning', text: 'The most common setup in your specs failed here; try the next trait combination or adjust the records in step 2.' }));
      els.result.appendChild(h('div', { class: 'muted', text: 'Go back, adjust the plan and run preflight again. Nothing was written.' }));
    }
    if (p.js_errors && p.js_errors.length) els.result.appendChild(h('div', { class: 'issue error', text: 'JavaScript errors: ' + p.js_errors.join('; ') }));
    if (p.screenshot) els.result.appendChild(h('img', { src: 'data:image/png;base64,' + p.screenshot, alt: 'start page' }));
  }

  function start() {
    els.startBtn.disabled = true;
    W.api.post('start', { plan: S.plan }).then(function (res) {
      if (!res.ok) { notice(res.error || 'could not start', true); els.startBtn.disabled = false; return; }
      S.status = 'recording';
      setStatus('recording', 'ok');
      showRecordingStatus(res.call_site);
    });
  }

  // B9: this window becomes the status screen of the recording that runs in
  // the other window: where it is, what it writes, a live step count, and
  // Save / Save & finish that act on the recorder (same endpoints as its toolbar).
  function recorderCommand(name) {
    return fetch('/__magic_test/commands', { method: 'POST', headers: { 'Content-Type': 'application/json' }, credentials: 'same-origin', body: JSON.stringify({ command: name }) })
      .then(function (r) { return r.json(); });
  }

  function showRecordingStatus(callSite) {
    var main = document.querySelector('main');
    main.innerHTML = '';
    document.querySelector('footer.nav').classList.add('hidden');
    var count = h('div', { class: 'count', id: 'recording-count', text: '0 steps' });
    var pending = h('pre', { class: 'code', id: 'recording-pending', text: '' });
    var msg = h('div', { class: 'muted', id: 'recording-message', text: '' });
    var front = h('button', { id: 'recording-front', class: 'primary', text: 'Bring the recording window to front', onclick: function () { recorderCommand('front'); } });
    var save = h('button', { id: 'recording-save', text: 'Save', title: 'Write the pending steps into the file (the recording goes on)', onclick: function () { recorderCommand('save').then(poll); } });
    var finish = h('button', { id: 'recording-finish', text: 'Save & finish', title: 'Write the pending steps and end the recording', onclick: function () { recorderCommand('save_and_finish').then(poll); } });
    var box = h('section', { id: 'recording-status' }, [
      h('h2', { text: 'Recording is running in the other window' }),
      h('p', { class: 'muted', text: 'Every step you take there is written above the magic_test line in:' }),
      h('div', { class: 'path', id: 'recording-path', text: callSite.path + ':' + callSite.line }),
      count,
      h('div', { class: 'actions' }, [front, save, finish]),
      msg,
      h('p', { class: 'muted', text: 'Pending code (not yet saved):' }),
      pending
    ]);
    main.appendChild(box);
    var timer = null;
    function poll() {
      return W.api.get('state').then(function (st) {
        if (!st || st.status === 'idle') return;
        var n = (st.steps || []).length;
        count.textContent = n + (n === 1 ? ' step' : ' steps') + ' · ' + (st.saved_count || 0) + ' saved';
        pending.textContent = (st.pending_code || []).join('\n') || '(nothing pending)';
        if (st.status === 'finished') {
          window.clearInterval(timer);
          setStatus('finished', 'ok');
          box.querySelector('h2').textContent = 'Recording finished';
          msg.textContent = 'The steps were written to ' + callSite.path + '. Run the spec to replay it; run bin/magic new again for the next test.';
          front.disabled = save.disabled = finish.disabled = true;
        }
      }).catch(function () { /* the server is between requests */ });
    }
    timer = window.setInterval(poll, 700);
    poll();
  }

  return { bind: bind, schedule: schedule, refresh: refresh, render: render, renderNav: renderNav, notice: notice };
})();
