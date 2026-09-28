// The stepper (1.2 §3): four steps in the left column, the skeleton pinned on
// the right. Fields keep the ids the 1.1 page used (#w-description, #w-path,
// #w-role, #w-role-trait-<t>, #w-model-<i>-…, #w-route, #w-param-<p>, …).
W.steps = (function () {
  var h = W.h;
  var S = W.state;
  var hint = function (key) { return W.hints.hint(key); };
  var root;

  var STEPS = [
    { n: 1, title: 'What & where', fields: /^(description|target)/ },
    { n: 2, title: 'Who & data', fields: /^(signed_in|models)/ },
    { n: 3, title: 'Start page & extras', fields: /^(start|extras)/ },
    { n: 4, title: 'Review & preflight', fields: /^$/ }
  ];

  function stepOfField(field) {
    var f = String(field || '');
    for (var i = 0; i < STEPS.length; i++) if (STEPS[i].fields.test(f)) return STEPS[i].n;
    return 4;
  }

  // ---- rendering --------------------------------------------------------------
  function render() {
    root = root || document.getElementById('form');
    root.innerHTML = '';
    var fn = [null, whatAndWhere, whoAndData, startAndExtras, review][S.step];
    root.appendChild(fn());
    renderIndicator();
    W.preview.renderNav();
  }

  function renderIndicator() {
    var ol = document.getElementById('steps');
    if (!ol) return;
    ol.innerHTML = '';
    STEPS.forEach(function (st) {
      var li = h('li', { id: 'step-' + st.n, class: (st.n === S.step ? 'current' : '') + (st.n < S.step ? ' done' : ''), onclick: function () { go(st.n); } }, [h('span', { class: 'n', text: String(st.n) }), st.title]);
      ol.appendChild(li);
    });
  }

  function changed(structural) {
    if (structural) render();
    W.preview.schedule();
  }

  // Errors for a field only after it was touched or Next was pressed on its step.
  function field(label, input, fieldKey, hintKey, note) {
    var labelable = input && input.id && /^(INPUT|SELECT|TEXTAREA)$/.test(input.tagName);
    var caption = labelable ? h('label', { class: 'lbl', for: input.id, text: label }) : h('span', { class: 'lbl', text: label });
    if (hintKey) caption.appendChild(hint(hintKey));
    var wrap = h('div', { class: 'field', 'data-field': fieldKey || '' }, [caption, input]);
    if (note) wrap.appendChild(h('span', { class: 'muted', text: ' ' + note }));
    if (input) input.addEventListener('change', function () { W.util.touch(fieldKey); });
    return wrap;
  }

  function section(title, children, hintKey) {
    var head = h('h2', { text: title });
    if (hintKey) head.appendChild(hint(hintKey));
    return h('section', { class: 'step' }, [head].concat(children));
  }

  // A filter input over a ranked list; optional groups (optgroup) keep the ranking inside each group.
  function picker(id, items, current, placeholder, onPick, labelFor, groupFor) {
    var filter = h('input', { type: 'text', id: id + '-filter', placeholder: placeholder, autocomplete: 'off' });
    var list = h('select', { id: id, size: Math.min(8, Math.max(3, items.length)) });
    var count = h('div', { class: 'count' });
    function fill() {
      var q = filter.value.toLowerCase();
      list.innerHTML = '';
      var shown = items.filter(function (it) { return !q || (labelFor ? labelFor(it) : it).toLowerCase().indexOf(q) >= 0; });
      var groups = {};
      var order = [];
      shown.forEach(function (it) {
        var g = groupFor ? groupFor(it) : '';
        if (!groups[g]) { groups[g] = []; order.push(g); }
        groups[g].push(it);
      });
      order.forEach(function (g) {
        var parent = g ? h('optgroup', { label: g }) : list;
        groups[g].forEach(function (it) {
          var value = typeof it === 'string' ? it : it.value;
          parent.appendChild(h('option', { value: value, text: labelFor ? labelFor(it) : it, selected: value === current }));
        });
        if (g) list.appendChild(parent);
      });
      count.textContent = shown.length === items.length ? items.length + ' in the list' : shown.length + ' of ' + items.length;
    }
    filter.addEventListener('input', fill);
    list.addEventListener('change', function () { onPick(list.value); });
    fill();
    return h('div', { class: 'picker' }, [filter, list, count]);
  }

  // ---- navigation -------------------------------------------------------------
  function stepErrors(n) {
    return S.issues.filter(function (i) { return i.severity === 'error' && stepOfField(i.field) === n; });
  }

  // Next validates against a fresh preview (typing is debounced), then moves on.
  function next() {
    if (S.step >= 4) return;
    var from = S.step;
    S.nextPressed[from] = true;
    return W.preview.refresh().then(function () {
      if (S.step !== from) return;
      if (stepErrors(from).length) { render(); W.preview.render(); return; }
      go(from + 1);
    });
  }

  function back() { if (S.step > 1) go(S.step - 1); }

  function go(n) {
    if (n < 1 || n > 4 || n === S.step) return;
    // Going forward past a step with errors is not allowed; going back always is.
    for (var i = S.step; i < n; i++) { S.nextPressed[i] = true; if (stepErrors(i).length) { S.step = i; render(); W.preview.render(); return; } }
    S.step = n;
    W.hints.close();
    render();
    W.preview.render();
    var first = root.querySelector('input:not([type=checkbox]), select');
    if (first && n < 4) first.focus();
  }

  // ---- step 1: what & where ---------------------------------------------------
  function whatAndWhere() {
    var cat = S.catalogue;
    var children = [];
    // Sources: starters, templates, last plan, blank.
    var cards = h('div', { class: 'cards' });
    (cat.starters || []).forEach(function (st) {
      var tag = st.ok === false ? h('span', { class: 'tag failed', text: 'failed last time: ' + (st.message || '').slice(0, 60) }) : h('span', { class: 'tag ' + (st.verified_at ? 'ok' : 'unknown'), text: W.util.agoText(st.verified_at) });
      var card = h('button', { type: 'button', class: 'card' + (S.source === 'starter:' + st.id ? ' selected' : ''), id: 'w-source-starter-' + st.id, disabled: !st.available,
        onclick: function () { loadPlan(st.plan, 'starter:' + st.id); } }, [
        h('span', { class: 'name', text: st.name }),
        h('span', { class: 'meta', text: st.available ? summarizePlan(st.plan) : 'not available here: ' + st.missing.join(', ') }),
        tag
      ]);
      cards.appendChild(card);
    });
    (cat.templates || []).forEach(function (t) {
      cards.appendChild(h('button', { type: 'button', class: 'card' + (S.source === 'template:' + t.slug ? ' selected' : ''), id: 'w-source-template-' + t.slug, onclick: function () { loadPlan(t.plan, 'template:' + t.slug); } }, [
        h('span', { class: 'name', text: 'Template: ' + t.name }), h('span', { class: 'meta', text: summarizePlan(t.plan) })
      ]));
    });
    if (cat.last_plan) cards.appendChild(h('button', { type: 'button', class: 'card' + (S.source === 'last' ? ' selected' : ''), id: 'w-source-last', onclick: function () { loadPlan(cat.last_plan, 'last'); } }, [h('span', { class: 'name', text: 'Last plan' }), h('span', { class: 'meta', text: (cat.last_plan.description || '') + ' · ' + summarizePlan(cat.last_plan) })]));
    cards.appendChild(h('button', { type: 'button', class: 'card' + (S.source === 'blank' ? ' selected' : ''), id: 'w-source-blank', onclick: function () { loadPlan(W.emptyPlan(), 'blank'); } }, [h('span', { class: 'name', text: 'Blank' }), h('span', { class: 'meta', text: 'start from nothing' })]));
    children.push(section('Start from', [cards], 'wizard.starters'));

    var desc = h('input', { type: 'text', id: 'w-description', value: S.plan.description, placeholder: 'e.g. provider edits a discount', autocomplete: 'off',
      oninput: function (e) { S.plan.description = e.target.value; W.util.touch('description'); if (!S.pathEdited) S.plan.target.path = suggestedPath(); changed(false); } });
    children.push(section('Describe the test', [field('What the person does (becomes the it name)', desc, 'description', 'wizard.description')]));

    // Target: new file or an existing one.
    var exists = !!(S.preview && S.preview.file_exists);
    var newBtn = h('button', { type: 'button', id: 'w-target-new', class: !S.targetExisting ? 'on' : '', onclick: function () { S.targetExisting = false; if (!S.pathEdited) S.plan.target.path = suggestedPath(); S.plan.target.block = null; changed(true); } }, ['New file']);
    var existingBtn = h('button', { type: 'button', id: 'w-target-existing', class: S.targetExisting ? 'on' : '', onclick: function () { S.targetExisting = true; changed(true); } }, ['Existing file']);
    var tchildren = [h('div', { class: 'choice' }, [newBtn, existingBtn])];
    var pathInput = h('input', { type: 'text', id: 'w-path', value: S.plan.target.path || '', placeholder: 'spec/system/<role>/<what>_spec.rb', autocomplete: 'off',
      oninput: function (e) { S.pathEdited = true; S.plan.target = { path: e.target.value, block: null }; W.util.touch('target.path'); changed(false); } });
    if (S.targetExisting) {
      var files = cat.files || [];
      tchildren.push(field('Existing spec (search, then pick)', picker('w-file', files, S.plan.target.path, 'search spec files…', function (value) { S.pathEdited = true; S.plan.target = { path: value, block: null }; W.util.touch('target.path'); changed(true); }), 'target.path', 'wizard.target_append'));
      tchildren.push(field('or type its path', pathInput, 'target.path'));
      if (exists && S.blocks.length) {
        var sel = h('select', { id: 'w-block', size: Math.min(8, Math.max(3, S.blocks.length)), onchange: function (e) { var b = S.blocks[parseInt(e.target.value, 10)]; S.plan.target.block = b ? b.ref : null; W.util.touch('target.block'); changed(false); } });
        S.blocks.forEach(function (b, i) {
          var chosen = S.plan.target.block && S.plan.target.block.path;
          var selected = chosen ? (JSON.stringify(chosen) === JSON.stringify(b.path) && (!S.plan.target.block.line || S.plan.target.block.line === b.first_line)) : i === 0;
          var lets = b.lets.length ? ' · lets: ' + b.lets.map(function (l) { return l.name; }).join(', ') : '';
          sel.appendChild(h('option', { value: String(i), text: '   '.repeat(b.path.length - 1) + b.label + lets, selected: selected }));
        });
        tchildren.push(field('Describe / context block to add the example to (from the file\'s tree)', sel, 'target.block', 'wizard.append_vs_context'));
      } else if (S.plan.target.path && !exists) {
        tchildren.push(h('div', { class: 'muted', text: 'That file does not exist yet; it will be created as a new file.' }));
      }
    } else {
      tchildren.push(field('Path of the new spec', pathInput, 'target.path', 'wizard.target_new_file', exists ? 'this file exists: the example will be appended to it' : 'suggested from the role and the description; change it if you like'));
    }
    children.push(section('Where the test goes', tchildren));
    return h('div', {}, children);
  }

  function summarizePlan(plan) {
    var models = (plan.models || []).map(function (m) { return m.factory + (m.traits && m.traits.length ? ' (' + m.traits.map(function (t) { return ':' + t; }).join(', ') + ')' : ''); });
    return (plan.signed_in ? 'signed in as ' + plan.signed_in : 'guest') + (models.length ? ' · ' + models.join(', ') : '') + (plan.start && plan.start.route ? ' · ' + plan.start.route : '');
  }

  // Loads a starter/template/last plan; a description already typed is kept.
  function loadPlan(plan, source) {
    var copy = JSON.parse(JSON.stringify(plan));
    var description = S.plan.description || (source.indexOf('starter:') === 0 ? '' : (copy.description || ''));
    var fresh = W.emptyPlan();
    S.plan = {
      description: description,
      target: { path: (copy.target && copy.target.path) || '', block: (copy.target && copy.target.block) || null },
      signed_in: copy.signed_in || null,
      models: (copy.models || []).map(function (m) { return { let: m.let, factory: m.factory, traits: (m.traits || []).slice(), count: m.count || 1, associations: m.associations || {}, attributes: m.attributes || {} }; }),
      start: { route: (copy.start && copy.start.route) || '', params: (copy.start && copy.start.params) || {}, locale: (copy.start && copy.start.locale) || fresh.start.locale },
      extras: Object.assign(fresh.extras, copy.extras || {})
    };
    if (copy.starter) S.plan.starter = copy.starter;
    S.source = source;
    S.pathEdited = !!S.plan.target.path;
    S.targetExisting = false;
    if (!S.plan.target.path) S.plan.target.path = suggestedPath();
    S.preflight = null; S.preflightedPlan = null;
    changed(true);
  }

  function suggestedPath() {
    var cls = W.util.roleClass();
    var dir = cls ? cls.split('::').pop().replace(/([a-z])([A-Z])/g, '$1_$2').toLowerCase() : 'public';
    var base = (S.plan.description || 'new').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'new';
    return 'spec/system/' + dir + '/' + base + '_spec.rb';
  }

  // ---- step 2: who & data -----------------------------------------------------
  function whoAndData() {
    var children = [];
    // Role
    var roles = S.catalogue.roles || [];
    var current = W.util.roleClass() || '';
    var sel = h('select', { id: 'w-role', onchange: function (e) { setRole(e.target.value); } });
    sel.appendChild(h('option', { value: '', text: 'guest / not signed in', selected: !current }));
    roles.forEach(function (r) { sel.appendChild(h('option', { value: r.class_name, text: r.class_name + '  — create(:' + r.factory + ')', selected: r.class_name === current })); });
    var rchildren = [field('Signed-in role', sel, 'signed_in', 'wizard.signed_in_role')];
    var model = W.util.signedInModel();
    if (model) {
      rchildren.push(field('Let name', h('input', { type: 'text', id: 'w-role-let', value: model.let, oninput: function (e) { renameLet(model, e.target.value); changed(false); } }), 'models[0].let', 'wizard.let_bang'));
      rchildren.push(traitsFor(model, 'w-role'));
      rchildren.push(h('div', { class: 'muted' }, ['Signed in with: ' + (S.preview && S.preview.skeleton && S.preview.skeleton.user_expression ? S.preview.skeleton.user_expression : model.let + '.user') + ' ', hint('wizard.magic_sign_in')]));
      if (W.util.classOf(model) === 'Student') rchildren.push(h('div', { class: 'muted', text: 'A new student gets the onboarding/welcome modals; the recorder captures their dismissal (Senere).' }));
    }
    children.push(section('Who is signed in', rchildren));

    // Records
    var mchildren = [];
    S.plan.models.forEach(function (m, i) { if (m.let !== S.plan.signed_in) mchildren.push(modelCard(m, i)); });
    var all = (S.catalogue.factories || []).slice();
    var learned = S.catalogue.learned || { factories: {} };
    var roleObj = W.util.roleFor(current);
    all.sort(function (a, b) {
      var la = learned.factories[a.name] || {}, lb = learned.factories[b.name] || {};
      var ra = [(roleObj && a.name === roleObj.factory) ? 0 : 1, la.infrastructure ? 1 : 0, -(la.usage || 0)];
      var rb = [(roleObj && b.name === roleObj.factory) ? 0 : 1, lb.infrastructure ? 1 : 0, -(lb.usage || 0)];
      for (var k = 0; k < 3; k++) if (ra[k] !== rb[k]) return ra[k] - rb[k];
      return a.name.localeCompare(b.name);
    });
    var visible = S.showAllFactories ? all : all.filter(function (f) { return !(learned.factories[f.name] || {}).infrastructure; });
    var hidden = all.length - visible.length;
    var chosen = { value: null };
    var pick = picker('w-factory', visible.map(function (f) { return { value: f.name, label: f.name + ((learned.factories[f.name] || {}).usage ? '  · used in ' + (learned.factories[f.name] || {}).usage + ' places' : '') }; }), null, 'search factories…',
      function (v) { chosen.value = v; }, function (it) { return it.label; });
    var addBtn = h('button', { type: 'button', id: 'w-add-model', text: 'Add record', onclick: function (e) { e.preventDefault(); var v = chosen.value || document.getElementById('w-factory').value; if (v) addModel(v); } });
    var addRow = h('div', {}, [h('span', { class: 'lbl muted' }, ['Add a record (factory) ', hint('wizard.factory')]), pick, addRow]);
    var controls = [addBtn];
    if (hidden > 0 || S.showAllFactories) controls.push(h('label', { class: 'muted', style: 'margin-left:8px' }, [h('input', { type: 'checkbox', id: 'w-factory-all', checked: S.showAllFactories, onchange: function (e) { S.showAllFactories = e.target.checked; render(); } }), ' show all (' + hidden + ' infrastructure factor' + (hidden === 1 ? 'y' : 'ies') + ' hidden)']));
    addRow.appendChild(h('div', { class: 'actions' }, controls));
    mchildren.push(addRow);
    children.push(section('Records the test needs', mchildren, 'wizard.let_bang'));
    return h('div', {}, children);
  }

  function setRole(className) {
    var old = W.util.signedInModel();
    if (old) S.plan.models.splice(S.plan.models.indexOf(old), 1);
    S.plan.signed_in = null;
    if (className) {
      var role = W.util.roleFor(className);
      var m = W.util.newModel(role.factory);
      S.plan.models.unshift(m);
      S.plan.signed_in = m.let;
    }
    if (!S.pathEdited) S.plan.target.path = suggestedPath();
    W.util.touch('signed_in');
    changed(true);
  }

  function renameLet(model, newName) {
    var oldName = model.let;
    model.let = newName;
    if (S.plan.signed_in === oldName) S.plan.signed_in = newName;
    S.plan.models.forEach(function (m) { Object.keys(m.associations).forEach(function (k) { if (m.associations[k] === oldName) m.associations[k] = newName; }); });
    Object.keys(S.plan.start.params).forEach(function (k) { if (S.plan.start.params[k] === oldName) S.plan.start.params[k] = newName; });
    S.plan.extras.flags.forEach(function (f) { if (f.actor === oldName) f.actor = newName; });
  }

  function traitsFor(model, prefix) {
    var f = W.util.factory(model.factory);
    if (!f || !f.traits.length) return h('div', { class: 'muted', text: 'no traits defined for :' + model.factory });
    var learned = W.util.learnedFactory(f.name);
    var box = h('div', { class: 'traits' });
    var usageOf = {};
    (learned.combinations || []).forEach(function (c) { c.traits.forEach(function (t) { usageOf[t] = (usageOf[t] || 0) + c.files; }); });
    f.traits.forEach(function (t) {
      var cb = h('input', { type: 'checkbox', id: prefix + '-trait-' + t, checked: model.traits.indexOf(t) >= 0, onchange: function (e) {
        if (e.target.checked) model.traits.push(t); else model.traits = model.traits.filter(function (x) { return x !== t; });
        W.util.touch('models.traits');
        changed(false);
      } });
      var isDefault = (learned.default_traits || []).indexOf(t) >= 0;
      box.appendChild(h('label', { class: 'trait-option', for: cb.id }, [cb, h('span', { class: 'trait-name', text: ':' + t }),
        usageOf[t] ? h('span', { class: 'usage', text: (isDefault ? 'used in ' + learned.default_traits_files + ' spec' + (learned.default_traits_files === 1 ? '' : 's') : 'in ' + usageOf[t] + ' spec' + (usageOf[t] === 1 ? '' : 's')) }) : null]));
    });
    var label = h('span', { class: 'lbl' }, ['Traits ', hint('wizard.trait')]);
    return h('div', { class: 'field', 'data-field': 'traits' }, [label, box]);
  }

  function addModel(factoryName) {
    S.plan.models.push(W.util.newModel(factoryName));
    W.util.touch('models');
    changed(true);
  }

  function modelCard(model, i) {
    var prefix = 'w-model-' + i;
    var assocs = (S.catalogue.associations || {})[model.factory] || [];
    var head = h('h3', {}, [
      h('span', {}, ['let!(:', h('input', { type: 'text', id: prefix + '-let', value: model.let, style: 'width:140px;display:inline-block', oninput: function (e) { renameLet(model, e.target.value); changed(false); } }), ') { create(:' + model.factory + ') }']),
      h('button', { type: 'button', id: prefix + '-remove', text: '×', title: 'remove', onclick: function (e) { e.preventDefault(); S.plan.models.splice(i, 1); changed(true); } })
    ]);
    var count = field('How many (create_list when > 1)', h('input', { type: 'number', id: prefix + '-count', min: 1, value: model.count || 1, oninput: function (e) { model.count = parseInt(e.target.value, 10) || 1; changed(false); } }), 'models[' + i + '].count', 'wizard.count');
    var assocBox = h('div', {});
    assocs.forEach(function (a) {
      var sel = h('select', { id: prefix + '-assoc-' + a.name, onchange: function (e) { model.associations[a.name] = e.target.value; W.util.touch('models[' + i + '].associations.' + a.name); changed(false); } });
      var current = model.associations[a.name];
      var sameClass = W.util.classOf(model) === a.class_name;
      var candidates = S.plan.models.filter(function (m) { return m !== model && (a.polymorphic || W.util.classOf(m) === a.class_name); });
      if (!current && candidates.length === 1 && !(sameClass && !a.required)) { current = candidates[0].let; model.associations[a.name] = current; }
      var opts = [['factory', a.required ? 'let the factory build it' : 'leave it to the factory (nil unless the factory sets it)']];
      candidates.forEach(function (m) { opts.push([m.let, (sameClass ? 'reuse ' : '') + m.let + '  (' + W.util.classOf(m) + ')']); });
      opts.push(['none', a.required ? 'none (nil) — NOT NULL, will fail' : 'none (nil)']);
      opts.forEach(function (o) { sel.appendChild(h('option', { value: o[0], text: o[1], selected: (current || 'factory') === o[0] })); });
      var missing = !current && candidates.length === 0 && !a.polymorphic && a.required;
      assocBox.appendChild(h('div', { class: 'assoc', 'data-field': 'models[' + i + '].associations.' + a.name }, [
        h('span', {}, [a.name + ' → ' + (a.class_name || 'polymorphic') + (a.required ? ' (required)' : ''), missing ? h('button', { type: 'button', text: 'add let!(:' + a.name + ')', style: 'margin-left:6px', onclick: function (e) { e.preventDefault(); addParent(model, a); } }) : null]),
        sel
      ]));
    });
    var attrBox = h('div', { class: 'attrs' });
    var attrNames = Object.keys((S.catalogue.attributes || {})[model.factory] || {});
    var common = W.util.learnedFactory(model.factory).kwargs || [];
    Object.keys(model.attributes).forEach(function (k) {
      attrBox.appendChild(h('div', { class: 'row', 'data-field': 'models[' + i + '].attributes.' + k }, [
        h('input', { type: 'text', value: k, list: prefix + '-attrs', placeholder: 'attribute', oninput: function (e) { var v = model.attributes[k]; delete model.attributes[k]; model.attributes[e.target.value] = v; k = e.target.value; W.preview.schedule(); } }),
        h('input', { type: 'text', value: model.attributes[k], placeholder: 'value', id: prefix + '-attr-' + k, oninput: function (e) { model.attributes[k] = e.target.value; W.preview.schedule(); } }),
        h('button', { type: 'button', text: '×', onclick: function (e) { e.preventDefault(); delete model.attributes[k]; changed(true); } })
      ]));
    });
    var datalist = h('datalist', { id: prefix + '-attrs' }, attrNames.map(function (n) { return h('option', { value: n }); }));
    var addAttr = h('input', { type: 'text', id: prefix + '-attr-add', list: prefix + '-attrs', placeholder: common.length ? 'e.g. ' + common.slice(0, 3).join(', ') + ' — type an attribute and press Enter' : 'type an attribute and press Enter', autocomplete: 'off',
      onkeydown: function (e) { if (e.key === 'Enter' && e.target.value) { e.preventDefault(); e.stopPropagation(); model.attributes[e.target.value] = ''; changed(true); } },
      onchange: function (e) { if (e.target.value && attrNames.indexOf(e.target.value) >= 0 && model.attributes[e.target.value] === undefined) { model.attributes[e.target.value] = ''; changed(true); } } });
    return h('div', { class: 'model', id: prefix }, [head, traitsFor(model, prefix), count,
      field('Associations', assocBox, 'models[' + i + '].associations', 'wizard.association'),
      field('Attribute overrides', h('div', {}, [attrBox, datalist, addAttr]), 'models[' + i + '].attributes', 'wizard.attribute_override')]);
  }

  function addParent(model, assoc) {
    var f = (S.catalogue.factories || []).filter(function (x) { return x.class_name === assoc.class_name; })[0];
    if (!f) return;
    var m = W.util.newModel(f.name, W.util.uniqueLet(assoc.name));
    S.plan.models.push(m);
    model.associations[assoc.name] = m.let;
    changed(true);
  }

  // ---- step 3: start page & extras ----------------------------------------------
  function humanPath(route) {
    try { return decodeURIComponent(route.path); } catch (e) { return route.path; }
  }

  function startAndExtras() {
    var children = [];
    var preferred = W.util.namespaceFor();
    var roleKey = W.util.roleClass() ? W.util.roleClass().split('::').pop().replace(/([a-z])([A-Z])/g, '$1_$2').toLowerCase() : 'guest';
    var visits = ((S.catalogue.learned || {}).routes || {})[roleKey] || {};
    var routes = (S.catalogue.routes || []).filter(function (r) { return r.namespace !== 'api' && !/^api_/.test(r.name) && !/\.json$/.test(r.path); }).sort(function (a, b) {
      var va = visits[a.name] || 0, vb = visits[b.name] || 0;
      if (va !== vb) return vb - va;
      var ra = rank(a), rb = rank(b);
      return ra !== rb ? ra - rb : a.name.localeCompare(b.name);
    });
    function rank(r) { return preferred.indexOf(r.namespace) >= 0 ? 0 : (r.namespace === 'public' ? 1 : 2); }
    var groups = {};
    routes.forEach(function (r) { groups[r.namespace] = true; });
    var pick = picker('w-route', routes.map(function (r) { return { value: r.name, label: r.name + '_path  ' + humanPath(r) + (visits[r.name] ? '  · visited in ' + visits[r.name] + ' spec' + (visits[r.name] === 1 ? '' : 's') : ''), group: r.namespace }; }), S.plan.start.route, 'search routes (name or path)…',
      function (v) { S.plan.start.route = v; S.plan.start.params = {}; W.util.touch('start.route'); changed(true); }, function (it) { return it.label; },
      Object.keys(groups).length > 1 ? function (it) { return it.group + (preferred.indexOf(it.group) >= 0 ? ' (this role)' : ''); } : null);
    var schildren = [field('Start page (the first visit)', pick, 'start.route', 'wizard.start_page')];
    var route = routes.filter(function (r) { return r.name === S.plan.start.route; })[0];
    if (route) {
      route.params.forEach(function (part) {
        var lets = W.util.letNames();
        var guess = S.plan.start.params[part] || lets.filter(function (l) { return part === l + '_id'; })[0] || (part === 'id' ? lets[lets.length - 1] : null);
        if (guess && !S.plan.start.params[part]) S.plan.start.params[part] = guess;
        var sel = h('select', { id: 'w-param-' + part, onchange: function (e) { S.plan.start.params[part] = e.target.value; W.util.touch('start.params.' + part); changed(false); } });
        sel.appendChild(h('option', { value: '', text: '— pick a let —' }));
        lets.forEach(function (l) { sel.appendChild(h('option', { value: l, text: l, selected: S.plan.start.params[part] === l })); });
        schildren.push(field(':' + part, sel, 'start.params.' + part, 'wizard.route_params'));
      });
      if (route.localized && S.catalogue.defaults.locales.length > 1) {
        var loc = h('select', { id: 'w-locale', onchange: function (e) { S.plan.start.locale = e.target.value; changed(false); } });
        S.catalogue.defaults.locales.forEach(function (l) { loc.appendChild(h('option', { value: l, text: l + (l === S.catalogue.defaults.locale ? ' (default, unprefixed)' : ' (/' + l + '/…)'), selected: S.plan.start.locale === l })); });
        schildren.push(field('Locale', loc, 'start.locale', 'wizard.locale'));
      }
    }
    children.push(section('Start page', schildren));

    var ex = S.plan.extras;
    var echildren = [];
    var flags = S.catalogue.flags || [];
    if (flags.length && S.catalogue.defaults.flipper) {
      var box = h('div', {});
      flags.forEach(function (f) {
        var entry = ex.flags.filter(function (x) { return x.name === f.name; })[0];
        var cb = h('input', { type: 'checkbox', id: 'w-flag-' + f.name, checked: !!entry, onchange: function (e) {
          ex.flags = ex.flags.filter(function (x) { return x.name !== f.name; });
          if (e.target.checked) ex.flags.push(S.plan.signed_in ? { name: f.name, actor: S.plan.signed_in } : { name: f.name });
          changed(true);
        } });
        var actor = h('select', { id: 'w-flag-actor-' + f.name, disabled: !entry, onchange: function (e) { entry.actor = e.target.value || undefined; if (!e.target.value) delete entry.actor; changed(false); } });
        actor.appendChild(h('option', { value: '', text: 'globally', selected: !(entry && entry.actor) }));
        W.util.letNames().forEach(function (l) { actor.appendChild(h('option', { value: l, text: 'for ' + l, selected: !!(entry && entry.actor === l) })); });
        box.appendChild(h('div', { class: 'assoc' }, [h('label', { class: 'trait-option', for: cb.id }, [cb, h('span', { text: ':' + f.name + (f.on_by_default ? '  (on by default)' : '') })]), actor]));
      });
      echildren.push(field('Flipper flags (referenced in the code)', box, 'extras.flags', 'wizard.flipper_global', 'per actor: ' + 'the flag is on for that record\'s user only'));
      echildren.push(h('div', { class: 'muted' }, ['Global or per actor? ', hint('wizard.flipper_actor')]));
    }
    echildren.push(field('Freeze time at (travel_to)', h('input', { type: 'text', id: 'w-travel', value: ex.travel_to || '', placeholder: 'e.g. 2026-12-24 10:00 (leave empty for the real clock)', oninput: function (e) { ex.travel_to = e.target.value || null; changed(false); } }), 'extras.travel_to', 'wizard.travel_to'));
    var vp = h('select', { id: 'w-viewport', onchange: function (e) { ex.viewport = e.target.value || null; changed(false); } });
    Object.keys(S.catalogue.viewports).forEach(function (k) { vp.appendChild(h('option', { value: k === 'desktop' ? '' : k, text: k + ' ' + S.catalogue.viewports[k].join('×'), selected: (ex.viewport || 'desktop') === k })); });
    echildren.push(field('Viewport', vp, 'extras.viewport', 'wizard.viewport'));
    var toggles = h('div', { class: 'traits' });
    if (!S.plan.signed_in) toggles.appendChild(h('label', { class: 'trait-option', for: 'w-cookie' }, [h('input', { type: 'checkbox', id: 'w-cookie', checked: ex.cookie_consent, onchange: function (e) { ex.cookie_consent = e.target.checked; changed(false); } }), h('span', { text: 'set the cookie consent cookie (guests)' })]));
    if (S.catalogue.defaults.sidekiq) toggles.appendChild(h('label', { class: 'trait-option', for: 'w-sidekiq' }, [h('input', { type: 'checkbox', id: 'w-sidekiq', checked: ex.sidekiq_inline, onchange: function (e) { ex.sidekiq_inline = e.target.checked; changed(false); } }), h('span', { text: 'run Sidekiq jobs inline for this test' }), hint('wizard.sidekiq_inline')]));
    toggles.appendChild(h('label', { class: 'trait-option', for: 'w-mail' }, [h('input', { type: 'checkbox', id: 'w-mail', checked: ex.mail_assertion, onchange: function (e) { ex.mail_assertion = e.target.checked; changed(false); } }), h('span', { text: 'assert on emails sent (clears deliveries first)' }), hint('wizard.mail_assertion')]));
    echildren.push(field('Jobs and mail', toggles, 'extras.jobs'));
    var fixtures = S.catalogue.fixture_files || [];
    if (fixtures.length) {
      var fx = h('div', { class: 'traits' });
      fixtures.forEach(function (name) {
        fx.appendChild(h('label', { class: 'trait-option', for: 'w-fixture-' + name }, [h('input', { type: 'checkbox', id: 'w-fixture-' + name, checked: ex.fixture_files.indexOf(name) >= 0, onchange: function (e) { ex.fixture_files = ex.fixture_files.filter(function (x) { return x !== name; }); if (e.target.checked) ex.fixture_files.push(name); changed(false); } }), h('span', { text: name })]));
      });
      echildren.push(field('Fixture files the test will upload', fx, 'extras.fixture_files', 'wizard.fixture_file'));
    }
    children.push(section('Extras', echildren));
    return h('div', {}, children);
  }

  // ---- step 4: review & preflight ------------------------------------------------
  function review() {
    var res = S.preview || {};
    var sk = res.skeleton;
    var children = [];
    var where = [];
    if (res.path) {
      var mode = sk ? sk.mode : 'new_file';
      var what = mode === 'new_file' ? 'A new file will be written:' : (mode === 'append_it' ? 'One example will be appended inside the chosen block of:' : 'A new context (with its own lets and before) will be added inside the chosen block of:');
      where.push(h('div', { class: 'muted', text: what }));
      where.push(h('div', { class: 'path', id: 'w-review-path', text: res.path + (sk && sk.insert_before_line ? '  (inserted before line ' + sk.insert_before_line + ')' : '') }));
      if (res.file_exists) where.push(h('div', { class: 'muted', text: 'The existing lines are kept as they are; a backup is written under tmp/magic_test/backups/ first. The green lines in the preview are the insertion.' }));
    }
    children.push(section('What will be written where', where, 'wizard.append_vs_context'));
    var summary = [];
    summary.push(h('div', {}, ['Signed in: ' + (S.plan.signed_in ? S.plan.signed_in + ' (' + W.util.roleClass() + ')' : 'guest')]));
    S.plan.models.forEach(function (m) { summary.push(h('div', { text: 'let!(:' + m.let + ') { create(:' + m.factory + (m.traits.length ? ', ' + m.traits.map(function (t) { return ':' + t; }).join(', ') : '') + ') }' + (m.count > 1 ? ' × ' + m.count : '') })); });
    summary.push(h('div', {}, ['Start page: ' + (S.plan.start.route ? S.plan.start.route + '_path' : '— none picked —')]));
    children.push(section('Plan', summary));
    var pf = [];
    pf.push(h('div', { class: 'muted' }, ['Preflight runs the setup for real in a second window: records, sign-in, start page. Nothing is written until it passes. ', hint('wizard.preflight')]));
    var actions = h('div', { class: 'actions' }, [
      h('button', { type: 'button', id: 'w-save-template', text: 'Save as template', onclick: saveTemplate }),
      h('span', { class: 'muted', id: 'w-template-saved', text: '' })
    ]);
    pf.push(actions);
    children.push(section('Preflight', pf, 'wizard.templates'));
    return h('div', {}, children);
  }

  function saveTemplate() {
    var name = window.prompt('Template name (saved under spec/magic_test/templates/):', S.plan.description || '');
    if (!name) return;
    W.api.post('save_template', { plan: S.plan, name: name }).then(function (res) {
      var el = document.getElementById('w-template-saved');
      if (res.ok) { if (el) el.textContent = 'saved: ' + res.path; S.catalogue.templates = res.templates || S.catalogue.templates; } else if (el) { el.textContent = res.error || 'could not save'; }
    });
  }

  return { render: render, next: next, back: back, go: go, stepOfField: stepOfField, stepErrors: stepErrors, loadPlan: loadPlan, STEPS: STEPS };
})();
