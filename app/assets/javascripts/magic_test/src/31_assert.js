// Assertions: from a text selection (have_content) or from a click in assert
// mode (have_css/have_field/have_checked_field/have_select/have_button/
// have_link/count), each with candidate locators for Ruby to rank.
MT.assert = (function () {
  function selectedText() {
    var sel = window.getSelection ? window.getSelection() : null;
    return sel ? MT.util.normalizeText(sel.toString()) : '';
  }

  function selectionContainer() {
    var sel = window.getSelection ? window.getSelection() : null;
    if (!sel || !sel.rangeCount) return null;
    var node = sel.getRangeAt(0).commonAncestorContainer;
    return node.nodeType === 1 ? node : node.parentElement;
  }

  // How many times the text occurs in the page's visible text.
  function occurrences(text) {
    var body = MT.util.normalizeText(document.body.innerText || document.body.textContent);
    var count = 0, idx = 0;
    while (text && (idx = body.indexOf(text, idx)) !== -1) { count += 1; idx += text.length; }
    return count;
  }

  function fromSelection(negative) {
    var text = selectedText();
    if (!text) { MT.toolbar && MT.toolbar.notify('Select some text first, then assert.'); return null; }
    var container = selectionContainer();
    var scope = null;
    if (occurrences(text) > 1 && container) {
      var scopes = MT.locators.scopesFor(container);
      scope = scopes.length ? { css: scopes[0].css, text: scopes[0].text || null } : null;
    }
    var event = { kind: 'assert', assertion: { type: negative ? 'no_content' : 'content', text: text, scope: scope, occurrences: occurrences(text) } };
    MT.transport.send(event);
    if (window.getSelection) window.getSelection().removeAllRanges();
    MT.toolbar && MT.toolbar.notify('Asserted: ' + text.slice(0, 60));
    return event;
  }

  function fromClick(target, e) {
    MT.typing.commitAll('assert'); // a value typed just before must come first
    var opts = MT.modes.options() || {};
    var type = opts.assertion_type || autoType(target);
    var assertion = { type: type, text: null };
    var candidates = [];
    switch (type) {
      case 'field':
        assertion.value = target.value;
        candidates = MT.locators.candidates(target, ['fillable_field']);
        break;
      case 'checked':
      case 'unchecked':
        candidates = MT.locators.candidates(target, [target.type === 'radio' ? 'radio_button' : 'checkbox'], { visibleAll: MT.util.isVisuallyHidden(target) });
        break;
      case 'select':
        assertion.selected = Array.from(target.selectedOptions || []).map(function (o) { return MT.util.normalizeText(o.textContent); })[0] || '';
        candidates = MT.locators.candidates(target, ['select'], { visibleAll: true });
        break;
      case 'button':
        assertion.disabled = MT.util.isDisabled(target);
        candidates = MT.locators.candidates(target, ['button', 'link_or_button']);
        break;
      case 'link':
        assertion.href = target.getAttribute('href');
        candidates = MT.locators.candidates(target, ['link', 'link_or_button']);
        break;
      case 'count': {
        var rowLike = target.closest('tr, li, .card') || target;
        var container = rowLike.closest('tbody, table, ul, ol, .row, .list-group') || rowLike.parentElement;
        var tag = rowLike.tagName.toLowerCase();
        var containerScopes = MT.locators.scopesFor(container);
        var containerCss = MT.dynamic.stableId(container) ? '#' + MT.util.cssEscape(container.id) : (containerScopes[0] ? containerScopes[0].css : null);
        var scopeNode = containerCss ? document.querySelector(containerCss) : container;
        assertion.selector = tag;
        assertion.count = Array.from((scopeNode || container).querySelectorAll(tag)).filter(MT.util.isVisible).length;
        assertion.scope = containerCss ? { css: containerCss } : null;
        break;
      }
      case 'no_css':
      case 'css':
      default:
        assertion.type = type === 'no_css' ? 'no_css' : 'css';
        assertion.text = MT.util.textOf(target).slice(0, 80) || null;
        candidates = MT.locators.cssCandidates(target);
        break;
    }
    var event = { kind: 'assert', assertion: assertion, target: MT.describe.describe(target), candidates: candidates, modal: MT.locators.currentModal(target) };
    MT.transport.send(event);
    MT.modes.set('record');
    MT.toolbar && MT.toolbar.notify('Assertion added (' + assertion.type + ')');
    return event;
  }

  function autoType(target) {
    if (MT.util.isCheckable(target)) return target.checked ? 'checked' : 'unchecked';
    if (MT.util.isTextLike(target)) return 'field';
    if (target.tagName === 'SELECT') return 'select';
    if (target.tagName === 'BUTTON' || MT.util.isSubmitLike(target)) return 'button';
    if (target.tagName === 'A' && target.hasAttribute('href')) return 'link';
    return 'css';
  }

  function currentPath() {
    MT.transport.send({ kind: 'assert', assertion: { type: 'current_path', path: MT.util.pathOnly(window.location.href) } });
  }

  return { fromSelection: fromSelection, fromClick: fromClick, currentPath: currentPath, selectedText: selectedText };
})();
