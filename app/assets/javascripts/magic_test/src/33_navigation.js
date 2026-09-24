// Page loads. `how` distinguishes an address-bar/typed navigation from one
// caused by a recorded click or submit (the server also sees every request).
MT.navigation = (function () {
  var KEY = 'magic_test.lastNav';

  function storage() { try { return window.sessionStorage; } catch (e) { return null; } }

  function markCause(cause) {
    var s = storage();
    if (s) { try { s.setItem(KEY, JSON.stringify({ cause: cause, at: Date.now() })); } catch (e) { /* ignore */ } }
  }

  function consumeCause() {
    var s = storage();
    if (!s) return null;
    var raw = s.getItem(KEY);
    if (!raw) return null;
    s.removeItem(KEY);
    try {
      var v = JSON.parse(raw);
      return (Date.now() - v.at < 15000) ? v.cause : null;
    } catch (e) { return null; }
  }

  function emit() {
    var cause = consumeCause();
    var nav = performance.getEntriesByType && performance.getEntriesByType('navigation')[0];
    var how = cause || ((nav && nav.type === 'reload') ? 'reload' : (document.referrer && new URL(document.referrer).origin === window.location.origin ? 'link' : 'typed'));
    if (how === 'link' && !cause) how = 'typed'; // same-origin referrer without a recorded click: the person typed/used history
    // The page the spec itself loaded before `magic_test` was called is not a step.
    var loadedAt = performance.timeOrigin || (performance.timing && performance.timing.navigationStart) || 0;
    if (MT.config && MT.config.started_at && loadedAt && loadedAt < MT.config.started_at) how = 'initial';
    MT.transport.send({ kind: 'navigation', how: how, path: MT.util.pathOnly(window.location.href), title: document.title, referrer: document.referrer || null });
  }

  function install() {
    // A recorded click/submit that unloads the page marks the next load as caused.
    window.addEventListener('beforeunload', function () {
      var last = MT.effects.lastUserEvent();
      if (last && Date.now() - last.ts < 5000) markCause(last.kind === 'enter' ? 'submit' : 'click');
    }, true);
    document.addEventListener('submit', function (e) { if (e.isTrusted) markCause('submit'); }, true);
  }

  return { install: install, emit: emit, markCause: markCause };
})();
