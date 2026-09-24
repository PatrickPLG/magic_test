// Observes what followed a user event: navigation, XHR/fetch (excluding
// background traffic such as the live-support widget), Bootstrap modals,
// toasts, window.open. Ruby uses this to decide `send_keys(:enter)`,
// `within('#ajax-modal')`, `window_opened_by` and assertion suggestions.
MT.effects = (function () {
  var lastUserEventAt = 0;
  var lastUserEvent = null;
  var backgroundUrls = {};
  var requestLog = [];
  var CAUSE_WINDOW_MS = 400;

  function markUserEvent(event) {
    lastUserEventAt = Date.now();
    lastUserEvent = event;
  }

  function ignored(path) {
    var patterns = (MT.config && MT.config.ignored_paths) || [];
    return patterns.some(function (src) { try { return new RegExp(src).test(path); } catch (e) { return false; } });
  }

  function classify(url) {
    var path = MT.util.pathOnly(url);
    if (ignored(path)) return false; // live support, cable, assets: never "caused" by a click
    var since = Date.now() - lastUserEventAt;
    var caused = since >= 0 && since < CAUSE_WINDOW_MS && !backgroundUrls[path];
    if (!caused) {
      backgroundUrls[path] = (backgroundUrls[path] || 0) + 1;
    }
    requestLog.push({ path: path, at: Date.now(), caused: caused });
    if (requestLog.length > 200) requestLog.shift();
    if (caused && lastUserEvent) {
      lastUserEvent.effects = lastUserEvent.effects || {};
      lastUserEvent.effects.xhr = true;
      lastUserEvent.effects.xhr_urls = (lastUserEvent.effects.xhr_urls || []).concat([path]);
      MT.transport.send({ kind: 'effect', trigger_event_id: lastUserEvent.id, effect: 'xhr', path: path });
    }
    return caused;
  }

  function install() {
    var origOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function (method, url) {
      try { this.__mtUrl = String(url); } catch (e) { /* ignore */ }
      return origOpen.apply(this, arguments);
    };
    var origSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.send = function () {
      try { if (this.__mtUrl && this.__mtUrl.indexOf('/__magic_test') === -1) classify(this.__mtUrl); } catch (e) { /* ignore */ }
      return origSend.apply(this, arguments);
    };
    if (window.fetch) {
      var origFetch = window.fetch;
      window.fetch = function (input, init) {
        try {
          var u = typeof input === 'string' ? input : (input && input.url);
          if (u && u.indexOf('/__magic_test') === -1) classify(u);
        } catch (e) { /* ignore */ }
        return origFetch.apply(window, arguments);
      };
    }
    // rails-ujs fires ajax:send on the remote form/link itself: unambiguous attribution.
    document.addEventListener('ajax:send', function (e) {
      if (lastUserEvent && Date.now() - lastUserEventAt < 2000) {
        lastUserEvent.effects = lastUserEvent.effects || {};
        lastUserEvent.effects.xhr = true;
        MT.transport.send({ kind: 'effect', trigger_event_id: lastUserEvent.id, effect: 'xhr', path: (e.target && (e.target.action || e.target.href)) || null });
      }
    }, true);
    window.addEventListener('beforeunload', function () {
      if (lastUserEvent && Date.now() - lastUserEventAt < 3000) {
        MT.transport.send({ kind: 'effect', trigger_event_id: lastUserEvent.id, effect: 'navigation' });
      }
      MT.transport.flush();
    }, true);
    document.addEventListener('shown.bs.modal', function (e) {
      var sel = e.target && e.target.id ? '#' + e.target.id : null;
      if (sel) MT.transport.send({ kind: 'modal', action: 'shown', selector: sel, trigger_event_id: lastUserEvent && lastUserEvent.id });
    }, true);
    document.addEventListener('hidden.bs.modal', function (e) {
      var sel = e.target && e.target.id ? '#' + e.target.id : null;
      if (sel) MT.transport.send({ kind: 'modal', action: 'hidden', selector: sel, after_submit: !!(lastUserEvent && lastUserEvent.effects && lastUserEvent.effects.xhr && Date.now() - lastUserEventAt < 5000) });
    }, true);
    document.addEventListener('shown.bs.toast', function (e) {
      var body = e.target && e.target.querySelector('.toast-body');
      var text = body ? MT.util.textOf(body) : MT.util.textOf(e.target);
      if (text) MT.transport.send({ kind: 'toast', text: text });
    }, true);
    // Bootstrap 5 dispatches native CustomEvents for shown/hidden (EventHandler.trigger), so no jQuery relay is needed.
  }

  function recentlyCausedRequest(withinMs) {
    var now = Date.now();
    return requestLog.some(function (r) { return r.caused && now - r.at < (withinMs || 1500); });
  }

  return { install: install, markUserEvent: markUserEvent, classify: classify, recentlyCausedRequest: recentlyCausedRequest, lastUserEvent: function () { return lastUserEvent; } };
})();
