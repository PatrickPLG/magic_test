// Boot: refuse to run twice, neutralise the legacy recorder if its globals
// are present, install listeners, connect to the session.
MT.boot = function () {
  if (window.MagicTest && window.MagicTest.__loaded) return;

  var legacy = typeof window.clickFunction === 'function' || typeof window.keypressFunction === 'function' || typeof window.initializeMutationObserver === 'function';
  if (legacy) {
    // The old partials are still rendered (Studiz app/views/magic_test copies).
    ['clickFunction', 'keypressFunction', 'keyDownFunction', 'keyUpFunction', 'mutationStart', 'mutationEnd', 'initializeMutationObserver', 'enableKeyboardShortcuts'].forEach(function (name) {
      try { window[name] = function () {}; } catch (e) { /* ignore */ }
    });
    try { if (window.mutationObserver && window.mutationObserver.disconnect) window.mutationObserver.disconnect(); } catch (e) { /* ignore */ }
    console.warn('magic_test: the legacy recorder partials are still rendered by this app; delete app/views/magic_test (see MIGRATION_STUDIZ.md). Legacy handlers were neutralised.');
  }

  MT.errors = [];
  var api = {
    __loaded: true,
    version: MT.version,
    legacyDetected: legacy,
    windowId: function () { return MT.windows.windowId(); },
    errors: function () { return MT.errors.slice(); },
    status: function () { return MT.session.status(); },
    modes: MT.modes,
    assert: { fromSelection: function (negative) { return MT.assert.fromSelection(negative); }, currentPath: function () { return MT.assert.currentPath(); } },
    // Exposed for the gem's own tests only.
    __internals: MT
  };
  window.MagicTest = api;

  MT.util.safe(function () { MT.windows.install(); });
  MT.util.safe(function () { MT.effects.install(); });
  MT.util.safe(function () { MT.dialogs.install(); });
  MT.util.safe(function () { MT.navigation.install(); });
  MT.util.safe(function () { MT.recording.install(); });
  MT.util.safe(function () { MT.selects.install(); });
  MT.util.safe(function () { MT.widgets.trix.install(); });
  var ready = function () {
    MT.util.safe(function () { MT.widgets.flatpickr.installAll(); });
    MT.util.safe(function () { MT.session.configure(); });
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', ready); else ready();
};
