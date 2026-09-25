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
    els.issues.innerHTML = '';
    document.querySelectorAll('.field-error').forEach(function (n) { n.remove(); });
    S.issues.forEach(function (issue) {
      var row = h('div', { class: 'issue ' + issue.severity }, [h('strong', { text: issue.field + ': ' }), issue.message, issue.fix ? h('span', { class: 'fix', text: 'fix: ' + issue.fix }) : null]);
      if (issue.data && issue.data.add_model) {
        row.appendChild(h('button', { text: 'add let!(:' + issue.data.add_model.let + ')', onclick: function () {
          S.plan.models.push({ let: issue.data.add_model.let, factory: issue.data.add_model.factory, traits: [], count: 1, associations: {}, attributes: {} });
          W.form.render(); schedule();
        } }));
      }
      els.issues.appendChild(row);
      var target = document.querySelector('[data-field="' + issue.field + '"]');
      if (target && issue.severity === 'error') target.appendChild(h('div', { class: 'field-error', text: issue.message }));
    });
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

  function renderPreflight() {
    var p = S.preflight;
    els.result.innerHTML = '';
    if (!p) return;
    if (p.ok) {
      els.result.appendChild(h('div', { class: 'ok', id: 'preflight-ok', text: '✓ Preflight passed: ' + p.status + ' ' + p.path + (p.title ? ' — ' + p.title : '') }));
      els.result.appendChild(h('div', { class: 'muted', text: 'Signed in as ' + (p.user || 'guest') + ' · ' + (p.records || []).map(function (r) { return r.let + ' = ' + r.class + '#' + r.id; }).join(', ') }));
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
      notice('Skeleton written to ' + res.call_site.path + ':' + res.call_site.line + '. Recording started in the other window; this one closes.');
      setStatus('recording', 'ok');
    });
  }

  return { bind: bind, schedule: schedule, refresh: refresh, render: render, notice: notice };
})();
