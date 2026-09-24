// Tiny in-browser test harness for the recorder's JS modules. Loaded into a
// fixture page by spec/js/js_unit_spec.rb; results are read back over CDP.
window.__mt = (function () {
  var results = [];
  var current = null;
  function describe(name, fn) { var prev = current; current = (prev ? prev + ' ' : '') + name; try { fn(); } finally { current = prev; } }
  function it(name, fn) {
    var full = (current ? current + ' ' : '') + name;
    try { fn(); results.push({ name: full, ok: true }); } catch (e) { results.push({ name: full, ok: false, error: String(e && e.message || e), stack: e && e.stack }); }
  }
  function fail(msg) { throw new Error(msg); }
  var assert = {
    ok: function (v, msg) { if (!v) fail(msg || ('expected truthy, got ' + JSON.stringify(v))); },
    equal: function (a, b, msg) { if (a !== b) fail((msg ? msg + ': ' : '') + 'expected ' + JSON.stringify(b) + ', got ' + JSON.stringify(a)); },
    deepEqual: function (a, b, msg) { var x = JSON.stringify(a), y = JSON.stringify(b); if (x !== y) fail((msg ? msg + ': ' : '') + 'expected ' + y + ', got ' + x); },
    includes: function (list, item, msg) { if (list.indexOf(item) === -1) fail((msg ? msg + ': ' : '') + JSON.stringify(list) + ' does not include ' + JSON.stringify(item)); },
    match: function (str, re, msg) { if (!re.test(str)) fail((msg ? msg + ': ' : '') + JSON.stringify(str) + ' does not match ' + re); }
  };
  return { describe: describe, it: it, assert: assert, results: function () { return results; }, reset: function () { results = []; },
    MT: function () { return window.MagicTest.__internals; } };
})();
