// Sends events to the server (the source of truth) with fetch keepalive so
// they survive navigation, keeps a small sessionStorage fallback buffer for
// events fired during unload, and polls the server state for the toolbar.
MT.transport = (function () {
  var BUFFER_KEY = 'magic_test.buffer';
  var SEQ_KEY = 'magic_test.seq';
  var queue = [];
  var sending = false;
  var seq = 0;
  var stateListeners = [];
  var lastState = null;
  var pollTimer = null;

  function storage() {
    try { return window.sessionStorage; } catch (e) { return null; }
  }

  function loadSeq() {
    var s = storage();
    seq = s ? parseInt(s.getItem(SEQ_KEY) || '0', 10) : 0;
  }

  function saveSeq() {
    var s = storage();
    if (s) { try { s.setItem(SEQ_KEY, String(seq)); } catch (e) { /* quota */ } }
  }

  function buffered() {
    var s = storage();
    if (!s) return [];
    try { return JSON.parse(s.getItem(BUFFER_KEY) || '[]'); } catch (e) { return []; }
  }

  function setBuffered(list) {
    var s = storage();
    if (!s) return;
    try { s.setItem(BUFFER_KEY, JSON.stringify(list)); } catch (e) { /* quota */ }
  }

  function url(path) {
    return '/__magic_test/' + path;
  }

  function stamp(event) {
    seq += 1;
    saveSeq();
    event.id = event.id || MT.util.uuid();
    event.seq = seq;
    event.ts = Date.now();
    event.url = event.url || MT.util.pathOnly(window.location.href);
    event.window = MT.windows ? MT.windows.identity() : { id: 'main' };
    event.frame = MT.windows ? MT.windows.frameIdentity() : null;
    return event;
  }

  function send(event) {
    stamp(event);
    queue.push(event);
    var buf = buffered(); buf.push(event); setBuffered(buf);
    flush();
    return event;
  }

  function flush() {
    if (sending || !queue.length) return;
    if (!(MT.session && MT.session.configured())) return; // events wait until the session config (XPath templates) is known
    var batch = queue.splice(0, queue.length);
    sending = true;
    var body = JSON.stringify({ session_id: MT.config && MT.config.session_id, events: batch });
    var done = function (ok, response) {
      sending = false;
      if (ok) {
        var acked = (response && response.acked) || batch.map(function (e) { return e.id; });
        setBuffered(buffered().filter(function (e) { return acked.indexOf(e.id) === -1; }));
        if (response && response.state) receiveState(response.state);
      } else {
        queue = batch.concat(queue);
        setTimeout(flush, 500);
      }
      if (queue.length) flush();
    };
    try {
      fetch(url('events'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: body, keepalive: true, credentials: 'same-origin' })
        .then(function (r) { return r.ok ? r.json() : Promise.reject(new Error('HTTP ' + r.status)); })
        .then(function (json) { done(true, json); })
        .catch(function () { done(false); });
    } catch (e) {
      done(false);
    }
  }

  // Events that never got an ack (fired during unload) are re-sent after load.
  function replayBuffer() {
    var buf = buffered();
    if (!buf.length) return;
    buf.forEach(function (e) { if (!queue.some(function (q) { return q.id === e.id; })) queue.push(e); });
    flush();
  }

  function command(name, params) {
    var body = JSON.stringify(Object.assign({ command: name }, params || {}));
    return fetch(url('commands'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: body, credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (json) { if (json.state) receiveState(json.state); return json; });
  }

  function fetchConfig() {
    return fetch(url('config'), { credentials: 'same-origin' }).then(function (r) { return r.json(); });
  }

  function fetchState() {
    return fetch(url('state'), { credentials: 'same-origin' }).then(function (r) { return r.json(); }).then(function (s) { receiveState(s); return s; });
  }

  function receiveState(state) {
    lastState = state;
    if (state && state.known_ids && MT.config) MT.config.known_ids = state.known_ids;
    stateListeners.forEach(function (fn) { MT.util.safe(function () { fn(state); }); });
  }

  function onState(fn) { stateListeners.push(fn); }

  // Events not yet acknowledged by the server (the toolbar and the scripted
  // human wait for 0 before asking the server to save).
  function pending() { return queue.length; }

  function startPolling(intervalMs) {
    stopPolling();
    pollTimer = setInterval(function () { fetchState().catch(function () {}); }, intervalMs || 700);
  }

  function stopPolling() { if (pollTimer) clearInterval(pollTimer); pollTimer = null; }

  loadSeq();

  return { send: send, flush: flush, pending: pending, replayBuffer: replayBuffer, command: command, fetchConfig: fetchConfig, fetchState: fetchState, onState: onState, startPolling: startPolling, stopPolling: stopPolling, lastState: function () { return lastState; } };
})();
