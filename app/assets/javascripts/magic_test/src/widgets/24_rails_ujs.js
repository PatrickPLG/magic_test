// rails-ujs `data-confirm`, native confirm()/alert()/prompt() from app JS and
// .js.erb responses. Cuprite auto-accepts native dialogs, so the recorder
// replaces them with a toolbar decision the person really makes. rails-ujs
// calls `window.confirm` at click time, so the stub applies to it as well.
MT.dialogs = (function () {
  var original = { confirm: window.confirm, alert: window.alert, prompt: window.prompt };
  var lastTrigger = null; // { event, element, at }
  var pending = null; // { id, type, message, element, event }
  var autoAnswer = null; // { accept: bool, response: string } for the re-triggered call

  function noteTrigger(event, element) {
    lastTrigger = { event: event, element: element, at: Date.now() };
  }

  function triggerEventId() {
    return lastTrigger && Date.now() - lastTrigger.at < 15000 ? lastTrigger.event.id : null;
  }

  function open(type, message, defaultValue) {
    var id = MT.util.uuid();
    pending = { id: id, type: type, message: String(message === undefined ? '' : message), element: lastTrigger && lastTrigger.element, event: lastTrigger && lastTrigger.event, defaultValue: defaultValue };
    MT.transport.send({ id: id, kind: 'dialog_opened', dialog_type: type, message: pending.message, trigger_event_id: triggerEventId() });
    if (MT.toolbar) MT.toolbar.showDialog(pending);
  }

  function record(answer, response) {
    if (!pending) return;
    var p = pending;
    pending = null;
    MT.transport.send({ kind: 'dialog', dialog_type: p.type, message: p.message, answer: answer, response: response || null, trigger_event_id: (p.event && p.event.id) || triggerEventId() });
    if (MT.toolbar) MT.toolbar.hideDialog();
    return p;
  }

  // The person accepted in the toolbar: replay the triggering action with the
  // stub answering true this once. For rails-ujs the re-click is untrusted,
  // which the recorder ignores (the original click is already recorded).
  function answer(accept, response) {
    if (!pending) return;
    var p = record(accept ? 'accept' : 'dismiss', response);
    if (accept && p.type !== 'alert' && p.element && document.contains(p.element)) {
      autoAnswer = { accept: true, response: response };
      setTimeout(function () {
        try { p.element.click(); } finally { autoAnswer = null; }
      }, 0);
    }
  }

  function install() {
    window.confirm = function (message) {
      if (autoAnswer) { var a = autoAnswer; autoAnswer = null; return a.accept; }
      if (!(MT.session && MT.session.recording())) return original.confirm.call(window, message);
      open('confirm', message);
      return false;
    };
    window.alert = function (message) {
      if (!(MT.session && MT.session.recording())) return original.alert.call(window, message);
      open('alert', message);
      // alerts need no decision: record immediately, keep the toolbar notice visible
      setTimeout(function () { if (pending && pending.type === 'alert') record('accept'); }, 0);
      return undefined;
    };
    window.prompt = function (message, defaultValue) {
      if (autoAnswer) { var a = autoAnswer; autoAnswer = null; return a.response === undefined ? (defaultValue || '') : a.response; }
      if (!(MT.session && MT.session.recording())) return original.prompt.call(window, message, defaultValue);
      open('prompt', message, defaultValue);
      return null;
    };
  }

  function applyServerAnswer(state) {
    if (!pending || !state || !state.dialog_answer) return;
    var a = state.dialog_answer;
    answer(a.answer === 'accept', a.response);
  }

  return { install: install, noteTrigger: noteTrigger, answer: answer, pending: function () { return pending; }, applyServerAnswer: applyServerAnswer, original: original };
})();
