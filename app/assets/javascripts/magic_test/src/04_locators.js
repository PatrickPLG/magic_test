// Candidate locators for an element and an intent, each with Capybara-
// semantics match counts, globally and inside stable scopes. Ruby ranks them.
MT.locators = (function () {
  function modalsOpen() {
    var list = (MT.config && MT.config.modals) || ['#ajax-modal', '#full-view-modal', '#image-cropper-modal'];
    var out = [];
    list.forEach(function (sel) {
      var m = document.querySelector(sel);
      if (m && m.classList.contains('show')) out.push({ kind: 'modal', css: sel, node: m });
    });
    document.querySelectorAll('.modal.show[id]').forEach(function (m) {
      if (!out.some(function (o) { return o.node === m; }) && MT.dynamic.stableId(m)) out.push({ kind: 'modal', css: '#' + MT.util.cssEscape(m.id), node: m });
    });
    return out;
  }

  // Unique text in a table row: the shortest cell text that no other row of
  // the same table contains.
  function rowScope(node) {
    var tr = node.closest('tr');
    if (!tr) return null;
    var table = tr.closest('table');
    var rows = Array.from((table || document).querySelectorAll('tr')).filter(function (r) { return r !== tr && MT.util.isVisible(r); });
    var cells = Array.from(tr.querySelectorAll('td, th')).map(function (c) { return MT.util.textOf(c); }).filter(function (t) { return t.length >= 2; });
    cells.sort(function (a, b) { return a.length - b.length; });
    for (var i = 0; i < cells.length; i++) {
      var text = cells[i];
      if (text.length > 80) continue;
      var clash = rows.some(function (r) { return MT.util.textOf(r).indexOf(text) !== -1; });
      if (!clash) return { kind: 'row', css: 'tr', text: text, node: tr };
    }
    return null;
  }

  function headingScope(node) {
    var container = node.parentElement;
    var depth = 0;
    while (container && container !== document.body && depth < 8) {
      var heading = container.querySelector('h1, h2, h3, h4, h5, h6, .card-title, .modal-title');
      if (heading && container.contains(heading)) {
        var text = MT.util.textOf(heading);
        var classes = MT.dynamic.semanticClasses(container);
        if (text && classes.length) {
          var css = container.tagName.toLowerCase() + '.' + classes.map(MT.util.cssEscape).join('.');
          var same = Array.from(document.querySelectorAll(css)).filter(function (c) { return MT.util.isVisible(c) && MT.util.textOf(c).indexOf(text) !== -1; });
          if (same.length === 1 && same[0] === container) return { kind: 'heading', css: css, text: text, node: container };
        }
      }
      container = container.parentElement;
      depth += 1;
    }
    return null;
  }

  function formScope(node) {
    var form = node.closest('form');
    if (!form) return null;
    var id = MT.dynamic.stableId(form);
    if (id && document.querySelectorAll('#' + MT.util.cssEscape(id)).length === 1) return { kind: 'form', css: '#' + MT.util.cssEscape(id), node: form };
    return null;
  }

  function ancestorScope(node) {
    var el = node.parentElement;
    var depth = 0;
    var max = (MT.config && MT.config.max_ancestor_depth) || 8;
    while (el && el !== document.body && depth < max) {
      var id = MT.dynamic.stableId(el);
      if (id && document.querySelectorAll('#' + MT.util.cssEscape(id)).length === 1) return { kind: 'ancestor', css: '#' + MT.util.cssEscape(id), node: el };
      var classes = MT.dynamic.semanticClasses(el);
      if (classes.length) {
        var css = el.tagName.toLowerCase() + '.' + classes.map(MT.util.cssEscape).join('.');
        try {
          if (document.querySelectorAll(css).length === 1) return { kind: 'ancestor', css: css, node: el };
        } catch (e) { /* ignore */ }
      }
      el = el.parentElement;
      depth += 1;
    }
    return null;
  }

  // Repeated containers such as client-side nested-field rows: the n-th
  // `.ticket-type-fields` (index among the visible ones).
  function nthScope(node) {
    var el = node.parentElement;
    var depth = 0;
    var max = (MT.config && MT.config.max_ancestor_depth) || 8;
    while (el && el !== document.body && depth < max) {
      var classes = MT.dynamic.semanticClasses(el);
      if (classes.length) {
        var css = el.tagName.toLowerCase() + '.' + classes.map(MT.util.cssEscape).join('.');
        var all;
        try { all = Array.from(document.querySelectorAll(css)).filter(MT.util.isVisible); } catch (e) { all = []; }
        if (all.length > 1 && all.indexOf(el) !== -1) return { kind: 'nth', css: css, index: all.indexOf(el), count: all.length, node: el };
      }
      el = el.parentElement;
      depth += 1;
    }
    return null;
  }

  function scopesFor(node) {
    var out = [];
    modalsOpen().forEach(function (m) { if (m.node.contains(node)) out.push(m); });
    var f = formScope(node); if (f) out.push(f);
    var r = rowScope(node); if (r) out.push(r);
    var h = headingScope(node); if (h) out.push(h);
    var a = ancestorScope(node); if (a) out.push(a);
    var n = nthScope(node); if (n) out.push(n);
    return out;
  }

  function plainScope(s) {
    return s ? { kind: s.kind, css: s.css, text: s.text || null, index: (s.index === undefined ? null : s.index), count: (s.count === undefined ? null : s.count) } : null;
  }

  // Semantic locator values for a Capybara selector kind.
  function semanticValues(node, kind) {
    var values = [];
    function add(by, value) {
      value = MT.util.normalizeText(value);
      if (!value) return;
      if (values.some(function (v) { return v.by === by && v.value === value; })) return;
      values.push({ by: by, value: value });
    }
    if (kind === 'link_or_button' || kind === 'link' || kind === 'button') {
      add('own_text', MT.util.ownText(node));
      add('text', MT.util.textOf(node));
      if (node.tagName === 'INPUT') add('value', node.value);
      var img = node.querySelector && node.querySelector('img[alt]');
      if (img) add('alt', img.getAttribute('alt'));
      add('title', node.getAttribute('title'));
      var sid = MT.dynamic.stableId(node); if (sid) add('id', sid);
      var sname = MT.dynamic.stableName(node); if (sname && node.tagName !== 'A') add('name', sname);
      // Capybara does not match aria-label by default (enable_aria_label false);
      // it is still reported so the toolbar can show it as a non-Capybara alternative.
    } else if (kind === 'trix') {
      add('label', MT.util.labelTextFor(node));
      var tid = MT.dynamic.stableId(node); if (tid) add('id', tid);
      var input = node.getAttribute('input'); if (input && !MT.dynamic.isDynamic(input)) add('input', input);
    } else {
      add('label', MT.util.labelTextFor(node));
      var fid = MT.dynamic.stableId(node); if (fid) add('id', fid);
      var fname = MT.dynamic.stableName(node); if (fname) add('name', fname);
      add('placeholder', node.placeholder);
    }
    return values;
  }

  // Candidates for `kind` (one of Capybara's selector names), global then scoped.
  function semanticCandidates(node, kind, options) {
    var out = [];
    var values = semanticValues(node, kind);
    var scopes = scopesFor(node);
    values.forEach(function (v) {
      if (kind === 'trix') {
        var trixCount = trixMatches(v, null);
        out.push({ kind: 'trix', by: v.by, locator: v.value, scope: null, exact: trixCount, partial: trixCount, unique: trixCount === 1 });
        return;
      }
      var c = MT.capybara.count(kind, v.value, document, node, options);
      out.push({ kind: kind, by: v.by, locator: v.value, scope: null, exact: c.exact, partial: c.partial, exact_supported: c.exact_supported, unique: c.unique && c.target_matches });
      if (!(c.unique && c.target_matches)) {
        scopes.forEach(function (s) {
          var sc = MT.capybara.count(kind, v.value, s.node, node, options);
          if (sc.unique && sc.target_matches) {
            out.push({ kind: kind, by: v.by, locator: v.value, scope: plainScope(s), exact: sc.exact, partial: sc.partial, exact_supported: sc.exact_supported, unique: true });
          }
        });
      }
    });
    return out;
  }

  function trixMatches(v, context) {
    var sel = v.by === 'id' ? 'trix-editor#' + MT.util.cssEscape(v.value) : (v.by === 'input' ? 'trix-editor[input="' + v.value + '"]' : null);
    if (!sel) {
      var labels = Array.from(document.querySelectorAll('label')).filter(function (l) { return MT.util.textOf(l).indexOf(v.value) !== -1 && l.htmlFor; });
      return labels.filter(function (l) { return document.querySelector('trix-editor#' + MT.util.cssEscape(l.htmlFor)); }).length;
    }
    return (context || document).querySelectorAll(sel).length;
  }

  // CSS candidates: stable id, name, data-bs-target/href pattern, semantic classes.
  function cssCandidates(node) {
    var out = [];
    var tag = node.tagName.toLowerCase();
    var scopes = scopesFor(node);
    var selectors = [];
    var id = MT.dynamic.stableId(node);
    if (id) selectors.push({ css: '#' + MT.util.cssEscape(id), by: 'id' });
    var name = MT.dynamic.stableName(node);
    if (name) selectors.push({ css: tag + '[name="' + name + '"]', by: 'name' });
    ['data-bs-target', 'data-bs-toggle', 'data-target', 'data-action', 'data-test', 'data-testid', 'aria-label', 'title'].forEach(function (a) {
      var val = node.getAttribute(a);
      if (val && !MT.dynamic.isDynamic(val)) selectors.push({ css: tag + '[' + a + '="' + val.replace(/"/g, '\\"') + '"]', by: 'attribute' });
    });
    if (node.tagName === 'A' && node.getAttribute('href') && node.getAttribute('href') !== '#') {
      var href = node.getAttribute('href');
      if (!MT.dynamic.isDynamic(href) && !/\d/.test(href)) selectors.push({ css: 'a[href="' + href.replace(/"/g, '\\"') + '"]', by: 'href' });
    }
    var classes = MT.dynamic.semanticClasses(node);
    if (classes.length) {
      selectors.push({ css: tag + '.' + classes.map(MT.util.cssEscape).join('.'), by: 'classes' });
      classes.forEach(function (c) { selectors.push({ css: tag + '.' + MT.util.cssEscape(c), by: 'class' }); });
    }
    var text = MT.util.textOf(node);
    selectors.push({ css: tag, by: 'tag' }); // last resort before positional: `td` with text, or inside a scope
    selectors.forEach(function (s) {
      var c = MT.capybara.cssCount(s.css, document, null, node);
      out.push({ kind: 'css', by: s.by, locator: s.css, scope: null, exact: c.exact, partial: c.partial, unique: c.unique && c.target_matches });
      if (!(c.unique && c.target_matches) && text && text.length <= 60) {
        var ct = MT.capybara.cssCount(s.css, document, text, node);
        if (ct.unique && ct.target_matches) out.push({ kind: 'css', by: s.by, locator: s.css, text: text, scope: null, exact: 1, partial: 1, unique: true });
      }
      if (!(c.unique && c.target_matches)) {
        scopes.forEach(function (sc) {
          var cc = MT.capybara.cssCount(s.css, sc.node, null, node);
          if (cc.unique && cc.target_matches) out.push({ kind: 'css', by: s.by, locator: s.css, scope: plainScope(sc), exact: 1, partial: 1, unique: true });
        });
      }
    });
    // Last resort: positional inside the nearest stable scope.
    var scope = scopes[0];
    if (scope) {
      var pos = positionalSelector(node, scope.node);
      if (pos) out.push({ kind: 'positional', by: 'positional', locator: pos, scope: plainScope(scope), exact: 1, partial: 1, unique: true });
    }
    return out;
  }

  function positionalSelector(node, scopeNode) {
    var parts = [];
    var el = node;
    while (el && el !== scopeNode && el !== document.body) {
      var index = 1;
      var sib = el.previousElementSibling;
      while (sib) { if (sib.tagName === el.tagName) index += 1; sib = sib.previousElementSibling; }
      parts.unshift(el.tagName.toLowerCase() + ':nth-of-type(' + index + ')');
      el = el.parentElement;
    }
    if (el !== scopeNode) return null;
    var css = parts.join(' > ');
    try { return scopeNode.querySelectorAll(css).length === 1 ? css : null; } catch (e) { return null; }
  }

  // All candidates for an intent: kinds is an array of Capybara selector names.
  function candidates(node, kinds, options) {
    var out = [];
    (kinds || []).forEach(function (k) { out = out.concat(semanticCandidates(node, k, options)); });
    out = out.concat(cssCandidates(node));
    return out;
  }

  function currentModal(node) {
    var m = modalsOpen().find(function (x) { return x.node.contains(node); });
    return m ? m.css : null;
  }

  return { candidates: candidates, scopesFor: scopesFor, modalsOpen: modalsOpen, currentModal: currentModal, semanticValues: semanticValues, cssCandidates: cssCandidates, rowScope: rowScope, positionalSelector: positionalSelector };
})();
