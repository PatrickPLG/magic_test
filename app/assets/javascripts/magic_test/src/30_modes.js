// Recorder modes: record (default), assert (next click becomes an assertion),
// hover (next click records a hover on that element).
MT.modes = (function () {
  var mode = 'record';
  var options = {};
  var listeners = [];
  var localChangeAt = 0;

  function set(next, opts) {
    localChangeAt = Date.now();
    mode = next || 'record';
    options = opts || {};
    listeners.forEach(function (fn) { MT.util.safe(function () { fn(mode, options); }); });
    MT.transport.command('set_mode', Object.assign({ mode: mode }, options)).catch(function () {});
  }

  // Server-driven mode (scripted human) without echoing it back.
  function sync(next, opts) {
    if (Date.now() - localChangeAt < 2000) return; // a state poll may still carry the mode from before our own change
    if (next === mode && JSON.stringify(opts || {}) === JSON.stringify(options || {})) return;
    mode = next || 'record';
    options = opts || {};
    listeners.forEach(function (fn) { MT.util.safe(function () { fn(mode, options); }); });
  }

  return { current: function () { return mode; }, options: function () { return options; }, set: set, sync: sync, onChange: function (fn) { listeners.push(fn); } };
})();
