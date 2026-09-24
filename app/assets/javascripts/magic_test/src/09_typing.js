// Text-like inputs and textareas: one `fill` per field with the final value,
// emitted on change/blur/Enter/submit/unload; consecutive edits of the same
// field coalesce on the server. Paste and autofill are covered because the
// value is read from the element, not reconstructed from key events.
MT.typing = (function () {
  var dirty = new Map(); // element -> initial value
  var lastEnterAt = 0;

  function recentEnter() {
    return Date.now() - lastEnterAt < 500;
  }

  function touched(el) {
    if (!dirty.has(el)) dirty.set(el, el.__mtInitialValue !== undefined ? el.__mtInitialValue : (el.defaultValue !== undefined ? el.defaultValue : ''));
  }

  function commit(el, reason) {
    if (!dirty.has(el)) return null;
    var initial = dirty.get(el);
    dirty.delete(el);
    var value = el.value;
    if (value === initial && reason !== 'enter') return null;
    if (el.closest && el.closest('.chosen-container, .flatpickr-calendar')) return null;
    if (el.classList.contains('chosen-search-input')) return null;
    var event = {
      kind: 'fill', target: MT.describe.describe(el), value: value,
      candidates: MT.locators.candidates(el, ['fillable_field']), modal: MT.locators.currentModal(el)
    };
    el.__mtInitialValue = value;
    MT.transport.send(event);
    return event;
  }

  function commitAll(reason) {
    Array.from(dirty.keys()).forEach(function (el) { commit(el, reason); });
  }

  // Enter in a text input: commit the value first, then record the Enter if a
  // submit/XHR/navigation actually followed (checked shortly after).
  function enter(el, e) {
    lastEnterAt = Date.now();
    commit(el, 'enter');
    var event = {
      kind: 'enter', target: MT.describe.describe(el), submitted: false,
      candidates: MT.locators.candidates(el, ['fillable_field']), modal: MT.locators.currentModal(el)
    };
    MT.effects.markUserEvent(event);
    var form = el.form;
    var submitted = false;
    var onSubmit = function () { submitted = true; };
    if (form) form.addEventListener('submit', onSubmit, true);
    var unload = function () { submitted = true; };
    window.addEventListener('beforeunload', unload, true);
    var finish = function () {
      if (form) form.removeEventListener('submit', onSubmit, true);
      window.removeEventListener('beforeunload', unload, true);
      event.submitted = submitted || MT.effects.recentlyCausedRequest(600) || !!(event.effects && (event.effects.xhr || event.effects.navigation));
      if (event.submitted) MT.transport.send(event);
    };
    // rails-ujs/jQuery submit handlers run synchronously on the submit event; XHR shows up a tick later.
    setTimeout(finish, 250);
    window.addEventListener('pagehide', function () { if (!event.submitted) { event.submitted = true; MT.transport.send(event); } }, { once: true, capture: true });
  }

  return { touched: touched, commit: commit, commitAll: commitAll, enter: enter, recentEnter: recentEnter };
})();
