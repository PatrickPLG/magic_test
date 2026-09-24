// Counts matches for a locator with Capybara's own XPath (compiled in Ruby,
// see MagicTest::CapybaraXPath) and Capybara's node filters (visibility,
// disabled), so uniqueness in the browser equals uniqueness in `page.all`.
MT.capybara = (function () {
  var PLACEHOLDER = '__MAGIC_TEST_LOCATOR__';

  function xpathLiteral(value) {
    value = String(value);
    if (value.indexOf("'") === -1) return "'" + value + "'";
    if (value.indexOf('"') === -1) return '"' + value + '"';
    return 'concat(' + value.split("'").map(function (part) { return "'" + part + "'"; }).join(', "\'", ') + ')';
  }

  function template(kind, exact) {
    var t = MT.config && MT.config.xpath && MT.config.xpath[kind];
    if (!t) return null;
    return exact ? t.exact : t.partial;
  }

  function compile(kind, locator, exact) {
    var t = template(kind, exact);
    if (!t) return null;
    // The placeholder sits inside a plain '...' literal; replace literal and quotes together.
    return t.split("'" + PLACEHOLDER + "'").join(xpathLiteral(locator));
  }

  function evaluate(xpath, context) {
    var nodes = [];
    try {
      var result = document.evaluate(xpath, context || document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
      for (var i = 0; i < result.snapshotLength; i++) nodes.push(result.snapshotItem(i));
    } catch (e) {
      MT.util.report(e);
    }
    return nodes;
  }

  function passesFilters(node, kind, options) {
    var filters = (MT.config.xpath[kind] && MT.config.xpath[kind].filters) || ['visible', 'disabled'];
    if (filters.indexOf('visible') !== -1 && !(options && options.visibleAll) && !MT.util.isVisible(node)) return false;
    if (filters.indexOf('disabled') !== -1 && MT.util.isDisabled(node)) return false;
    if (filters.indexOf('disabled_unless_link') !== -1 && node.tagName !== 'A' && MT.util.isDisabled(node)) return false;
    return true;
  }

  // Elements Capybara's `all(kind, locator, exact: exact)` would return.
  function matches(kind, locator, context, exact, options) {
    var xpath = compile(kind, locator, exact);
    if (!xpath) return [];
    return evaluate(xpath, context).filter(function (n) { return passesFilters(n, kind, options); });
  }

  // { exact: n, partial: n, unique: bool, target_matches: bool }
  function count(kind, locator, context, target, options) {
    if (!MT.config || !MT.config.xpath || !MT.config.xpath[kind]) {
      return { exact: 0, partial: 0, exact_supported: true, unique: false, target_matches: false };
    }
    var exactNodes = matches(kind, locator, context, true, options);
    var partialNodes = matches(kind, locator, context, false, options);
    // Lightweight diagnostic ring buffer (inspectable through window.MagicTest.__internals.trace).
    MT.trace = MT.trace || [];
    MT.trace.push({ kind: kind, locator: locator, exact: exactNodes.length, partial: partialNodes.length, raw: evaluate(compile(kind, locator, false), context).length, at: Date.now() });
    if (MT.trace.length > 100) MT.trace.shift();
    var exactSupported = !(MT.config.xpath[kind] && MT.config.xpath[kind].exact_supported === false);
    var chosen = exactSupported ? (exactNodes.length ? exactNodes : partialNodes) : partialNodes;
    return {
      exact: exactNodes.length, partial: partialNodes.length,
      exact_supported: exactSupported,
      unique: chosen.length === 1,
      target_matches: !target || chosen.indexOf(target) !== -1
    };
  }

  function cssCount(selector, context, text, target) {
    var nodes;
    try { nodes = Array.from((context || document).querySelectorAll(selector)); } catch (e) { return { exact: 0, partial: 0, unique: false, target_matches: false }; }
    nodes = nodes.filter(function (n) { return MT.util.isVisible(n); });
    if (text) {
      var norm = MT.util.normalizeText(text);
      nodes = nodes.filter(function (n) { return MT.util.textOf(n).indexOf(norm) !== -1; });
    }
    return { exact: nodes.length, partial: nodes.length, exact_supported: true, unique: nodes.length === 1, target_matches: !target || nodes.indexOf(target) !== -1 };
  }

  return { compile: compile, evaluate: evaluate, matches: matches, count: count, cssCount: cssCount, xpathLiteral: xpathLiteral };
})();
