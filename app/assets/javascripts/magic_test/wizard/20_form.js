// The left column: one section per question.
W.form = (function () {
  var h = W.h;
  var S = W.state;
  var root;

  function render() {
    root = root || document.getElementById('form');
    root.innerHTML = '';
    root.appendChild(descriptionSection());
    root.appendChild(targetSection());
    root.appendChild(roleSection());
    root.appendChild(modelsSection());
    root.appendChild(startSection());
    root.appendChild(extrasSection());
  }

  function changed(structural) {
    if (structural) render();
    W.preview.schedule();
  }

  function field(label, input, fieldKey, hint) {
    var wrap = h('label', { class: 'field', 'data-field': fieldKey || '' }, [h('span', { class: 'lbl', text: label }), input]);
    if (hint) wrap.appendChild(h('span', { class: 'muted', text: ' ' + hint }));
    return wrap;
  }

  function section(title, children) {
    return h('section', { class: 'step' }, [h('h2', { text: title })].concat(children));
  }

  // ---- description ----------------------------------------------------------
  function descriptionSection() {
    var input = h('input', { type: 'text', id: 'w-description', value: S.plan.description, placeholder: 'provider edits a discount',
      oninput: function (e) { S.plan.description = e.target.value; changed(false); } });
    return section('1 · Describe the test', [field('Description (becomes the it name and a comment)', input, 'description')]);
  }

  // ---- target ---------------------------------------------------------------
  // One path: typed, or picked from the existing system specs. When the file
  // exists the preview lists its describe/context blocks and the example is
  // appended there; otherwise a new file is written.
  function targetSection() {
    var files = S.catalogue.files || [];
    var children = [];
    children.push(field('Spec file (an existing file appends an example; a new path creates the file)', h('input', { type: 'text', id: 'w-path', value: S.plan.target.path || suggestedPath(),
      oninput: function (e) { S.plan.target = { path: e.target.value, block: null }; changed(false); } }), 'target.path', S.preview && S.preview.file_exists ? 'exists → append' : 'new file'));
    if (files.length) {
      children.push(h('div', { class: 'muted', text: 'or pick an existing spec:' }));
      children.push(picker('w-file', files, S.plan.target.path, 'filter files…', function (value) { S.plan.target = { path: value, block: null }; document.getElementById('w-path').value = value; changed(false); }));
    }
    if (S.preview && S.preview.file_exists && S.blocks.length) {
      var sel = h('select', { id: 'w-block', onchange: function (e) { S.plan.target.block = e.target.value ? [e.target.value] : null; changed(false); } });
      S.blocks.forEach(function (b, i) {
        var last = b.path[b.path.length - 1];
        sel.appendChild(h('option', { value: last, text: b.path.join(' › ') + ' (' + b.kind + '; lets: ' + b.lets.map(function (l) { return l.name; }).join(', ') + ')', selected: (S.plan.target.block ? S.plan.target.block[0] === last : i === 0) }));
      });
      children.push(field('Describe / context block to add the example to', sel, 'target.block'));
    }
    return section('2 · Where the test goes', children);
  }

  function suggestedPath() {
    var cls = W.util.roleClass();
    var dir = cls ? cls.split('::').pop().replace(/([a-z])([A-Z])/g, '$1_$2').toLowerCase() : 'public';
    var base = (S.plan.description || 'new').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'new';
    return 'spec/system/' + dir + '/' + base + '_spec.rb';
  }

  // A filter input over a list; the callback gets the chosen value.
  function picker(id, items, current, placeholder, onPick, labelFor) {
    var filter = h('input', { type: 'text', id: id + '-filter', placeholder: placeholder, autocomplete: 'off' });
    var list = h('select', { id: id, size: Math.min(8, Math.max(3, items.length)) });
    function fill() {
      var q = filter.value.toLowerCase();
      list.innerHTML = '';
      items.filter(function (it) { return !q || (labelFor ? labelFor(it) : it).toLowerCase().indexOf(q) >= 0; }).forEach(function (it) {
        var value = typeof it === 'string' ? it : it.value;
        list.appendChild(h('option', { value: value, text: labelFor ? labelFor(it) : it, selected: value === current }));
      });
    }
    filter.addEventListener('input', fill);
    list.addEventListener('change', function () { onPick(list.value); });
    fill();
    return h('div', { class: 'picker' }, [filter, list]);
  }

  // ---- role -----------------------------------------------------------------
  function roleSection() {
    var roles = S.catalogue.roles || [];
    var current = W.util.roleClass() || '';
    var sel = h('select', { id: 'w-role', onchange: function (e) { setRole(e.target.value); } });
    sel.appendChild(h('option', { value: '', text: 'guest / not signed in', selected: !current }));
    roles.forEach(function (r) { sel.appendChild(h('option', { value: r.class_name, text: r.class_name + '  — create(:' + r.factory + ')', selected: r.class_name === current })); });
    var children = [field('Signed-in role', sel, 'signed_in')];
    var model = W.util.signedInModel();
    if (model) {
      children.push(h('div', { class: 'row' }, [field('Let name', h('input', { type: 'text', id: 'w-role-let', value: model.let, oninput: function (e) { renameLet(model, e.target.value); changed(false); } }), 'models[0].let')]));
      children.push(traitsFor(model, 'w-role'));
      children.push(h('div', { class: 'muted', text: 'Signed in with: ' + (S.preview && S.preview.skeleton && S.preview.skeleton.user_expression ? S.preview.skeleton.user_expression : model.let + '.user') }));
      if (W.util.classOf(model) === 'Student') children.push(h('div', { class: 'muted', text: 'A new student gets the onboarding/welcome modals; the recorder captures their dismissal (Senere).' }));
    }
    return section('3 · Who is signed in', children);
  }

  function setRole(className) {
    var old = W.util.signedInModel();
    if (old) S.plan.models.splice(S.plan.models.indexOf(old), 1);
    S.plan.signed_in = null;
    if (className) {
      var role = W.util.roleFor(className);
      var letName = W.util.uniqueLet(role.factory.split('_').pop());
      S.plan.models.unshift({ let: letName, factory: role.factory, traits: [], count: 1, associations: {}, attributes: {} });
      S.plan.signed_in = letName;
      if (!(S.preview && S.preview.file_exists)) S.plan.target.path = suggestedPath();
    }
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
    var box = h('div', { class: 'traits' });
    f.traits.forEach(function (t) {
      var cb = h('input', { type: 'checkbox', id: prefix + '-trait-' + t, checked: model.traits.indexOf(t) >= 0, onchange: function (e) {
        if (e.target.checked) model.traits.push(t); else model.traits = model.traits.filter(function (x) { return x !== t; });
        changed(false);
      } });
      box.appendChild(h('label', {}, [cb, ' :' + t]));
    });
    return field('Traits', box, 'traits');
  }

  // ---- models ---------------------------------------------------------------
  function modelsSection() {
    var children = [];
    S.plan.models.forEach(function (model, i) { if (model.let !== S.plan.signed_in) children.push(modelCard(model, i)); });
    var factories = (S.catalogue.factories || []).map(function (f) { return f.name; });
    var chosen = { value: null };
    var pick = picker('w-factory', factories, null, 'search factories…', function (v) { chosen.value = v; });
    var addBtn = h('button', { id: 'w-add-model', text: 'Add model', onclick: function (e) { e.preventDefault(); var v = chosen.value || document.getElementById('w-factory').value; if (v) addModel(v); } });
    children.push(h('div', {}, [h('span', { class: 'lbl muted', text: 'Add a record (factory)' }), pick, addBtn]));
    return section('4 · Records the test needs', children);
  }

  function addModel(factoryName) {
    var f = W.util.factory(factoryName);
    S.plan.models.push({ let: W.util.uniqueLet(f.name.split('_').pop()), factory: f.name, traits: [], count: 1, associations: {}, attributes: {} });
    changed(true);
  }

  function modelCard(model, i) {
    var prefix = 'w-model-' + i;
    var assocs = (S.catalogue.associations || {})[model.factory] || [];
    var head = h('h3', {}, [
      h('span', {}, ['let!(:', h('input', { type: 'text', id: prefix + '-let', value: model.let, style: 'width:140px;display:inline-block', oninput: function (e) { renameLet(model, e.target.value); changed(false); } }), ') { create(:' + model.factory + ') }']),
      h('button', { id: prefix + '-remove', text: '×', title: 'remove', onclick: function (e) { e.preventDefault(); S.plan.models.splice(i, 1); changed(true); } })
    ]);
    var count = field('How many (create_list when > 1)', h('input', { type: 'number', id: prefix + '-count', min: 1, value: model.count || 1, oninput: function (e) { model.count = parseInt(e.target.value, 10) || 1; changed(false); } }), 'models[' + i + '].count');
    var assocBox = h('div', {});
    assocs.forEach(function (a) {
      var sel = h('select', { id: prefix + '-assoc-' + a.name, onchange: function (e) { model.associations[a.name] = e.target.value; changed(false); } });
      var current = model.associations[a.name];
      var candidates = S.plan.models.filter(function (m) { return m !== model && (a.polymorphic || W.util.classOf(m) === a.class_name); });
      if (!current && candidates.length === 1) { current = candidates[0].let; model.associations[a.name] = current; }
      var opts = [];
      if (!current || current === 'factory') opts.push(['factory', 'let the factory build it']);
      candidates.forEach(function (m) { opts.push([m.let, m.let + '  (' + W.util.classOf(m) + ')']); });
      if (current && current !== 'factory') opts.unshift(['factory', 'let the factory build it']);
      opts.push(['none', a.required ? 'none (nil) — NOT NULL, will fail' : 'none (nil)']);
      opts.forEach(function (o) { sel.appendChild(h('option', { value: o[0], text: o[1], selected: (current || 'factory') === o[0] })); });
      var missing = !current && candidates.length === 0 && !a.polymorphic;
      assocBox.appendChild(h('div', { class: 'assoc', 'data-field': 'models[' + i + '].associations.' + a.name }, [
        h('span', {}, [a.name + ' → ' + (a.class_name || 'polymorphic') + (a.required ? ' (required)' : ''), missing ? h('button', { text: 'add let!(:' + a.class_name.split('::').pop().replace(/([a-z])([A-Z])/g, '$1_$2').toLowerCase() + ')', style: 'margin-left:6px', onclick: function (e) { e.preventDefault(); addParent(model, a); } }) : null]),
        sel
      ]));
    });
    var attrBox = h('div', { class: 'attrs' });
    var attrNames = Object.keys((S.catalogue.attributes || {})[model.factory] || {});
    Object.keys(model.attributes).forEach(function (k) {
      attrBox.appendChild(h('div', { class: 'row', 'data-field': 'models[' + i + '].attributes.' + k }, [
        h('input', { type: 'text', value: k, list: prefix + '-attrs', placeholder: 'attribute', oninput: function (e) { var v = model.attributes[k]; delete model.attributes[k]; model.attributes[e.target.value] = v; k = e.target.value; W.preview.schedule(); } }),
        h('input', { type: 'text', value: model.attributes[k], placeholder: 'value', id: prefix + '-attr-' + k, oninput: function (e) { model.attributes[k] = e.target.value; W.preview.schedule(); } }),
        h('button', { text: '×', onclick: function (e) { e.preventDefault(); delete model.attributes[k]; changed(true); } })
      ]));
    });
    var datalist = h('datalist', { id: prefix + '-attrs' }, attrNames.map(function (n) { return h('option', { value: n }); }));
    var addAttr = h('button', { id: prefix + '-attr-add', text: 'Add attribute override', onclick: function (e) { e.preventDefault(); var name = prompt('Attribute name (' + attrNames.slice(0, 8).join(', ') + '…)'); if (name) { model.attributes[name] = ''; changed(true); } } });
    return h('div', { class: 'model', id: prefix }, [head, traitsFor(model, prefix), count, field('Associations', assocBox, 'models[' + i + '].associations'), field('Attribute overrides', h('div', {}, [attrBox, datalist, addAttr]), 'models[' + i + '].attributes')]);
  }

  function addParent(model, assoc) {
    var f = (S.catalogue.factories || []).filter(function (x) { return x.class_name === assoc.class_name; })[0];
    if (!f) return;
    var letName = W.util.uniqueLet(f.name.split('_').pop());
    S.plan.models.push({ let: letName, factory: f.name, traits: [], count: 1, associations: {}, attributes: {} });
    model.associations[assoc.name] = letName;
    changed(true);
  }

  // ---- start page -----------------------------------------------------------
  function startSection() {
    var preferred = W.util.namespaceFor();
    var routes = (S.catalogue.routes || []).slice().sort(function (a, b) {
      var ra = rank(a), rb = rank(b);
      return ra !== rb ? ra - rb : a.name.localeCompare(b.name);
    });
    function rank(r) { return preferred.indexOf(r.namespace) >= 0 ? 0 : (r.namespace === 'public' ? 1 : 2); }
    var pick = picker('w-route', routes.map(function (r) { return { value: r.name, label: r.name + '_path  ' + r.path + '  [' + r.namespace + ']' }; }), S.plan.start.route, 'search routes…',
      function (v) { S.plan.start.route = v; S.plan.start.params = {}; changed(true); }, function (it) { return it.label; });
    var children = [field('Start page (the first visit)', pick, 'start.route')];
    var route = routes.filter(function (r) { return r.name === S.plan.start.route; })[0];
    if (route) {
      route.params.forEach(function (part) {
        var lets = W.util.letNames();
        var guess = S.plan.start.params[part] || lets.filter(function (l) { return part === l + '_id'; })[0] || (part === 'id' ? lets[lets.length - 1] : null);
        if (guess && !S.plan.start.params[part]) S.plan.start.params[part] = guess;
        var sel = h('select', { id: 'w-param-' + part, onchange: function (e) { S.plan.start.params[part] = e.target.value; changed(false); } });
        sel.appendChild(h('option', { value: '', text: '— pick a let —' }));
        lets.forEach(function (l) { sel.appendChild(h('option', { value: l, text: l, selected: S.plan.start.params[part] === l })); });
        children.push(field(':' + part, sel, 'start.params.' + part));
      });
      if (route.localized && S.catalogue.defaults.locales.length > 1) {
        var loc = h('select', { id: 'w-locale', onchange: function (e) { S.plan.start.locale = e.target.value; changed(false); } });
        S.catalogue.defaults.locales.forEach(function (l) { loc.appendChild(h('option', { value: l, text: l + (l === S.catalogue.defaults.locale ? ' (default, unprefixed)' : ' (/' + l + '/…)'), selected: S.plan.start.locale === l })); });
        children.push(field('Locale', loc, 'start.locale'));
      }
    }
    return section('5 · Start page', children);
  }

  // ---- extras ---------------------------------------------------------------
  function extrasSection() {
    var ex = S.plan.extras;
    var children = [];
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
        box.appendChild(h('div', { class: 'assoc' }, [h('label', {}, [cb, ' :' + f.name + (f.on_by_default ? '  (on by default)' : '')]), actor]));
      });
      children.push(field('Flipper flags', box, 'extras.flags'));
    }
    children.push(field('Freeze time at (travel_to)', h('input', { type: 'text', id: 'w-travel', value: ex.travel_to || '', placeholder: '2026-12-24 10:00', oninput: function (e) { ex.travel_to = e.target.value || null; changed(false); } }), 'extras.travel_to'));
    var vp = h('select', { id: 'w-viewport', onchange: function (e) { ex.viewport = e.target.value || null; changed(false); } });
    Object.keys(S.catalogue.viewports).forEach(function (k) { vp.appendChild(h('option', { value: k === 'desktop' ? '' : k, text: k + ' ' + S.catalogue.viewports[k].join('×'), selected: (ex.viewport || 'desktop') === k })); });
    children.push(field('Viewport', vp, 'extras.viewport'));
    if (!S.plan.signed_in) children.push(h('label', {}, [h('input', { type: 'checkbox', id: 'w-cookie', checked: ex.cookie_consent, onchange: function (e) { ex.cookie_consent = e.target.checked; changed(false); } }), ' set the cookie consent cookie (guests)']));
    if (S.catalogue.defaults.sidekiq) children.push(h('label', {}, [h('input', { type: 'checkbox', id: 'w-sidekiq', checked: ex.sidekiq_inline, onchange: function (e) { ex.sidekiq_inline = e.target.checked; changed(false); } }), ' run Sidekiq jobs inline for this test (Sidekiq::Testing.inline!)']));
    children.push(h('label', {}, [h('input', { type: 'checkbox', id: 'w-mail', checked: ex.mail_assertion, onchange: function (e) { ex.mail_assertion = e.target.checked; changed(false); } }), ' assert on emails sent (clears deliveries; the recorder suggests the assertion)']));
    var fixtures = S.catalogue.fixture_files || [];
    if (fixtures.length) {
      var fx = h('div', {});
      fixtures.forEach(function (name) {
        fx.appendChild(h('label', {}, [h('input', { type: 'checkbox', id: 'w-fixture-' + name, checked: ex.fixture_files.indexOf(name) >= 0, onchange: function (e) { ex.fixture_files = ex.fixture_files.filter(function (x) { return x !== name; }); if (e.target.checked) ex.fixture_files.push(name); changed(false); } }), ' ' + name]));
      });
      children.push(field('Fixture files the test will upload', fx, 'extras.fixture_files'));
    }
    return section('6 · Extras', children);
  }

  return { render: render };
})();
