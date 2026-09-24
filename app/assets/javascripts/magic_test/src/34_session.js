// Client view of the server-side session: config (Capybara XPath templates,
// known ids), status polling, and applying server-driven answers/modes.
MT.session = (function () {
  var status = 'idle';
  var configured = false;
  var listeners = [];

  function recording() {
    return status === 'recording';
  }

  function applyState(state) {
    if (!state) return;
    if (!configured) return; // a poll or a queued event answered before the config arrived
    var prev = status;
    status = state.status || 'idle';
    if (state.mode) MT.modes.sync(state.mode, state.mode_options || {});
    MT.dialogs.applyServerAnswer(state);
    if (prev !== status) listeners.forEach(function (fn) { MT.util.safe(function () { fn(status, state); }); });
    if (status === 'finished') MT.transport.stopPolling();
  }

  function configure() {
    return MT.transport.fetchConfig().then(function (cfg) {
      if (!cfg || cfg.status === 'idle' || !cfg.xpath) {
        // No session yet (magic_test not reached): poll until one exists.
        MT.config = MT.config || {};
        MT.config.status = 'idle';
        status = 'idle';
        setTimeout(configure, 1000);
        return false;
      }
      MT.config = cfg;
      configured = true;
      status = cfg.status;
      MT.transport.replayBuffer();
      MT.transport.flush();
      MT.transport.startPolling(cfg.poll_interval_ms || 700);
      MT.navigation.emit();
      if (MT.toolbar && cfg.toolbar !== false) MT.toolbar.mount();
      listeners.forEach(function (fn) { MT.util.safe(function () { fn(status, cfg); }); });
      return true;
    }).catch(function () {
      setTimeout(configure, 1500);
      return false;
    });
  }

  MT.transport.onState(applyState);

  return { recording: recording, status: function () { return status; }, configure: configure, configured: function () { return configured; }, onStatus: function (fn) { listeners.push(fn); } };
})();
