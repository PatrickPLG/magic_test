// The right column: live preview, issues (with field-level errors),
// preflight and start.
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
    els.preflightBtn = document.getElementById('preflight');
    els.startBtn = document.getElementById('start');
    els.cancelBtn = document.getElementById('cancel');
    els.result = document.getElementById('preflight-result');
    els.preflightBtn.addEventListener('click', runPreflight);
    els.startBtn.addEventListener('click', start);
    els.cancelBtn.addEventListener('click', function () { if (confirm('Cancel the wizard? Nothing has been written.')) W.api.post('cancel', {}).then(function () { notice('Cancelled. You can close this window.', true); }); });
  }

  var schedule = W.util.debounce(function () { refresh(); }, 250);

  function refresh() {
    return W.api.post('preview', { plan: S.plan }).then(function (res) {
      S.preview = res;
      S.issues = res.issues || [];
      S.blocks = res.blocks || [];
      adoptWiring(res.plan);
      render();
      var wantBlocks = !!(res.file_exists && S.blocks.length);
      if (wantBlocks !== !!document.getElementById('w-block')) W.form.render();
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

  function render() {
    var res = S.preview || {};
    els.preview.textContent = (res.skeleton && res.skeleton.source) || (res.ok === false ? '# fix the issues on the left to see the skeleton' : '…');
    els.path.textContent = res.path ? (res.skeleton ? res.skeleton.mode.replace('_', ' ') + ' → ' : '') + res.path : '';
    renderChips();
    els.issues.innerHTML = '';
    document.querySelectorAll('.field-error').forEach(function (n) { n.remove(); });
    // B6: errors stay above the code; warnings and hints fold into a <details>.
    var folded = [];
    S.issues.forEach(function (issue) {
      var row = h('div', { class: 'issue ' + issue.severity }, [h('strong', { text: issue.field + ': ' }), issue.message, issue.fix ? h('span', { class: 'fix', text: (issue.severity === 'hint' ? '' : 'fix: ') + issue.fix }) : null]);
      if (issue.data && issue.data.add_model) {
        row.appendChild(h('button', { text: 'add let!(:' + issue.data.add_model.let + ')', onclick: function () {
          S.plan.models.push({ let: issue.data.add_model.let, factory: issue.data.add_model.factory, traits: [], count: 1, associations: {}, attributes: {} });
          W.form.render(); schedule();
        } }));
      }
      if (issue.severity === 'error') {
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
    var changedSincePreflight = !S.preflightedPlan || JSON.stringify(S.preflightedPlan) !== JSON.stringify(S.plan);
    els.preflightBtn.disabled = !(res.ok && S.status !== 'preflighting' && S.status !== 'recording');
    els.startBtn.disabled = !(S.preflight && S.preflight.ok && !changedSincePreflight && S.status === 'preflighted');
    setStatus(S.status, S.status === 'planning' && S.issues.some(function (i) { return i.severity === 'error'; }) ? 'err' : (S.status === 'preflighted' ? 'ok' : ''));
  }

  function setStatus(text, cls) {
    els.status.textContent = text;
    els.status.className = 'status ' + (cls || '');
  }

  function notice(text, error) {
    els.notice.textContent = text;
    els.notice.className = 'notice' + (error ? ' error' : '');
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
      renderPreflight();
      render();
    }).catch(function (e) { S.status = 'planning'; notice('preflight request failed: ' + e, true); render(); });
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
            W.form.render();
            schedule();
          } })
        ]));
      });
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
      els.result.appendChild(h('div', { class: 'muted', text: 'Edit the plan on the left and run preflight again. Nothing was written.' }));
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

  return { bind: bind, schedule: schedule, refresh: refresh, render: render, notice: notice };
})();
