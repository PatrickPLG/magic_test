// Utilities shared by every module. `MT` is the bundle-private namespace.
MT.util = (function () {
  var counter = 0;

  function uuid() {
    counter += 1;
    var rnd = (window.crypto && window.crypto.getRandomValues) ? Array.from(window.crypto.getRandomValues(new Uint8Array(6))).map(function (b) { return ('0' + b.toString(16)).slice(-2); }).join('') : Math.random().toString(16).slice(2, 14);
    return 'e-' + Date.now().toString(36) + '-' + rnd + '-' + counter;
  }

  // Capybara's text normalisation: collapse whitespace, trim.
  function normalizeText(text) {
    return (text || '').replace(/[​‎‏]/g, '').replace(/[\s ]+/g, ' ').trim();
  }

  // Cuprite's Node#visible? (javascripts/index.js#isVisible): display,
  // visibility and opacity up the ancestor chain. `_cuprite` is used when
  // present so the recording session and Capybara agree byte for byte.
  function isVisible(node) {
    if (!node || node.nodeType !== 1) return false;
    if (window._cuprite && typeof window._cuprite.isVisible === 'function') {
      try { return window._cuprite.isVisible(node); } catch (e) { /* fall through */ }
    }
    var el = node;
    if (el.tagName === 'AREA') {
      var map = el.closest('map');
      el = map ? document.querySelector('img[usemap="#' + map.getAttribute('name') + '"]') : null;
      if (!el) return false;
    }
    while (el) {
      var style = window.getComputedStyle(el);
      if (style.display === 'none' || style.visibility === 'hidden' || parseFloat(style.opacity) === 0) return false;
      el = el.parentElement;
    }
    return true;
  }

  // "Visually hidden" in the Bootstrap/Studiz sense: present and enabled but
  // not clickable (visually-hidden class, zero size, opacity 0, off-screen).
  function isVisuallyHidden(node) {
    if (!node) return false;
    if (!isVisible(node)) return true;
    if (node.classList.contains('visually-hidden') || node.classList.contains('sr-only')) return true;
    var rect = node.getBoundingClientRect();
    if (rect.width <= 1 && rect.height <= 1) return true;
    var style = window.getComputedStyle(node);
    if (style.clip === 'rect(0px, 0px, 0px, 0px)' || style.clipPath === 'inset(50%)') return true;
    return false;
  }

  var DISABLED_XPATH = 'parent::optgroup[@disabled] | ancestor::select[@disabled] | parent::fieldset[@disabled] | ' +
    'ancestor::*[not(self::legend) or preceding-sibling::legend][parent::fieldset[@disabled]]';

  function isDisabled(node) {
    if (!node) return false;
    if (node.disabled) return true;
    try {
      return document.evaluate(DISABLED_XPATH, node, null, XPathResult.BOOLEAN_TYPE, null).booleanValue;
    } catch (e) { return false; }
  }

  function cssEscape(ident) {
    if (window.CSS && CSS.escape) return CSS.escape(ident);
    return String(ident).replace(/[^a-zA-Z0-9_-]/g, '\\$&');
  }

  function attr(node, name) {
    return node && node.getAttribute ? node.getAttribute(name) : null;
  }

  function textOf(node) {
    if (!node) return '';
    if (node.tagName === 'INPUT' || node.tagName === 'TEXTAREA') return normalizeText(node.value);
    return normalizeText(node.textContent);
  }

  // Direct text nodes only (skips badges, icons, nested spans).
  function ownText(node) {
    if (!node) return '';
    var parts = [];
    for (var i = 0; i < node.childNodes.length; i++) {
      var child = node.childNodes[i];
      if (child.nodeType === 3) parts.push(child.textContent);
    }
    return normalizeText(parts.join(' '));
  }

  // Label text the way Capybara sees it (`normalize-space(string(label))`).
  function labelsFor(node) {
    var labels = [];
    if (!node) return labels;
    if (node.labels && node.labels.length) {
      for (var i = 0; i < node.labels.length; i++) labels.push(node.labels[i]);
    } else if (node.id) {
      document.querySelectorAll('label[for="' + cssEscape(node.id) + '"]').forEach(function (l) { labels.push(l); });
    }
    var wrapping = node.closest && node.closest('label');
    if (wrapping && labels.indexOf(wrapping) === -1) labels.push(wrapping);
    return labels;
  }

  function labelTextFor(node) {
    var labels = labelsFor(node);
    for (var i = 0; i < labels.length; i++) {
      var t = textOf(labels[i]);
      if (t) return t;
    }
    return '';
  }

  function isTextLike(node) {
    if (!node || node.nodeType !== 1) return false;
    if (node.tagName === 'TEXTAREA') return true;
    if (node.tagName !== 'INPUT') return false;
    var type = (node.type || 'text').toLowerCase();
    return ['text', 'password', 'email', 'number', 'search', 'tel', 'url', 'date', 'month', 'week', 'time', 'datetime-local', 'color', 'range'].indexOf(type) !== -1;
  }

  function isCheckable(node) {
    return node && node.tagName === 'INPUT' && (node.type === 'checkbox' || node.type === 'radio');
  }

  function isSubmitLike(node) {
    return node && node.tagName === 'INPUT' && ['submit', 'button', 'image', 'reset'].indexOf(node.type) !== -1;
  }

  function fingerprint(node) {
    if (!node) return '';
    return [node.tagName, node.type || '', node.id || '', node.name || '', labelTextFor(node)].join('|');
  }

  function pathOnly(url) {
    try {
      var u = new URL(url, window.location.href);
      return u.pathname + u.search;
    } catch (e) { return url; }
  }

  function safe(fn, fallback) {
    try { return fn(); } catch (e) { MT.util.report(e); return fallback; }
  }

  // The recorder must never throw into the page (js_errors: true would fail
  // the spec). Errors are kept for the toolbar.
  function report(error) {
    MT.errors = MT.errors || [];
    MT.errors.push(String(error && error.stack || error));
    if (MT.errors.length > 50) MT.errors.shift();
  }

  function once(fn) {
    var done = false, result;
    return function () { if (!done) { done = true; result = fn.apply(this, arguments); } return result; };
  }

  return {
    uuid: uuid, normalizeText: normalizeText, isVisible: isVisible, isVisuallyHidden: isVisuallyHidden,
    isDisabled: isDisabled, cssEscape: cssEscape, attr: attr, textOf: textOf, ownText: ownText,
    labelsFor: labelsFor, labelTextFor: labelTextFor, isTextLike: isTextLike, isCheckable: isCheckable,
    isSubmitLike: isSubmitLike, fingerprint: fingerprint, pathOnly: pathOnly, safe: safe, report: report, once: once
  };
})();
