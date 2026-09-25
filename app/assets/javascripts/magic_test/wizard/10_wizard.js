// The new-test wizard page (served at /__magic_test/new). Plain DOM, no
// framework: a plan object mirrors the YAML the engine understands, every
// change re-renders the affected section and asks the server for a preview
// (validation + skeleton). Preflight and start go through the same JSON
// endpoints the terminal wizard's engine uses.
W.api = {
  get: function (path) { return fetch('/__magic_test/' + path, { credentials: 'same-origin' }).then(function (r) { return r.json(); }); },
  post: function (name, body) {
    return fetch('/__magic_test/wizard/' + name, { method: 'POST', headers: { 'Content-Type': 'application/json' }, credentials: 'same-origin', body: JSON.stringify(body || {}) })
      .then(function (r) { return r.json(); });
  }
};

W.state = {
  catalogue: null,
  plan: { description: '', target: { path: '', block: null }, signed_in: null, models: [], start: { route: '', params: {}, locale: 'da' },
    extras: { flags: [], travel_to: null, viewport: null, cookie_consent: true, sidekiq_inline: false, mail_assertion: false, fixture_files: [] } },
  preview: null,
  issues: [],
  blocks: [],
  preflight: null,
  preflightedPlan: null,
  status: 'planning'
};

W.h = function (tag, attrs, children) {
  var el = document.createElement(tag);
  Object.keys(attrs || {}).forEach(function (k) {
    if (k === 'text') el.textContent = attrs[k];
    else if (k === 'html') el.innerHTML = attrs[k];
    else if (k.indexOf('on') === 0) el.addEventListener(k.slice(2), attrs[k]);
    else if (k === 'checked' || k === 'disabled' || k === 'selected' || k === 'multiple') { if (attrs[k]) el[k] = true; }
    else if (k === 'value') el.value = attrs[k];
    else el.setAttribute(k, attrs[k]);
  });
  (children || []).forEach(function (c) { if (c === null || c === undefined) return; el.appendChild(typeof c === 'string' ? document.createTextNode(c) : c); });
  return el;
};

W.util = {
  debounce: function (fn, ms) { var t; return function () { clearTimeout(t); t = setTimeout(fn, ms); }; },
  factory: function (name) { return (W.state.catalogue.factories || []).filter(function (f) { return f.name === name || (f.aliases || []).indexOf(name) >= 0; })[0]; },
  roleFor: function (className) { return (W.state.catalogue.roles || []).filter(function (r) { return r.class_name === className; })[0]; },
  classOf: function (model) { var f = model && W.util.factory(model.factory); return f ? f.class_name : null; },
  letNames: function () { return W.state.plan.models.map(function (m) { return m.let; }); },
  uniqueLet: function (base) { var names = W.util.letNames(); var n = base; var i = 2; while (names.indexOf(n) >= 0) { n = base + '_' + (i++); } return n; },
  signedInModel: function () { var p = W.state.plan; return p.models.filter(function (m) { return m.let === p.signed_in; })[0] || null; },
  roleClass: function () { return W.util.classOf(W.util.signedInModel()); },
  namespaceFor: function () {
    var cls = W.util.roleClass();
    if (!cls) return ['public'];
    var key = cls.split('::').pop().replace(/([a-z])([A-Z])/g, '$1_$2').toLowerCase();
    if (key === 'admin' || key === 'team_member') key = 'backoffice';
    return [key];
  }
};
