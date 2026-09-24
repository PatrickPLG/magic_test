// Capture-phase listeners that normalise raw DOM events into intent events.
// The element is resolved at pointerdown, before app handlers can mutate or
// remove it; only trusted events are honoured; duplicates are dropped per
// element (same element, same intent, within 300 ms).
MT.recording = (function () {
  var DEDUPE_MS = 300;
  var lastIntent = { key: null, at: 0 };
  var pendingTarget = null;
  var pendingTargetAt = 0;
  var paused = false;
  var widgets = [];

  function isOurs(target) {
    var host = MT.toolbar && MT.toolbar.host();
    return !!(host && target && (target === host || (host.contains && host.contains(target)) || (target.getRootNode && target.getRootNode() !== document && target.getRootNode().host === host)));
  }

  function eventTarget(e) {
    var path = e.composedPath ? e.composedPath() : null;
    var t = (path && path[0]) || e.target;
    if (t && t.nodeType === 3) t = t.parentElement;
    return t;
  }

  function active() {
    return MT.session && MT.session.recording() && !paused;
  }

  function dedupe(key) {
    var now = Date.now();
    if (lastIntent.key === key && now - lastIntent.at < DEDUPE_MS) return true;
    lastIntent = { key: key, at: now };
    return false;
  }

  // Nearest actionable ancestor for clicks on icons/spans inside controls.
  var ACTIONABLE = 'a, button, [role="button"], label, summary, input[type="submit"], input[type="button"], input[type="image"], input[type="checkbox"], input[type="radio"], [onclick], [data-bs-toggle], [data-bs-dismiss], [data-toggle], [data-method], [data-confirm], select, textarea, input';
  function retarget(node) {
    if (!node || node.nodeType !== 1) return node;
    var actionable = node.closest(ACTIONABLE);
    return actionable || node;
  }

  function registerWidget(widget) {
    widgets.push(widget);
  }

  // Widgets get first refusal on pointerdown/click/change/input.
  function widgetHandles(type, e, target) {
    for (var i = 0; i < widgets.length; i++) {
      var w = widgets[i];
      if (w[type] && MT.util.safe(function () { return w[type](e, target); }, false)) return true;
    }
    return false;
  }

  function onPointerDown(e) {
    if (!e.isTrusted || !active()) return;
    var t = eventTarget(e);
    if (isOurs(t)) return;
    pendingTarget = retarget(t);
    pendingTargetAt = Date.now();
    widgetHandles('pointerdown', e, pendingTarget);
  }

  function onClick(e) {
    if (!e.isTrusted || !active()) return;
    var raw = eventTarget(e);
    if (isOurs(raw)) return;
    var target = (pendingTarget && Date.now() - pendingTargetAt < 2000 && (pendingTarget === raw || pendingTarget.contains(raw) || raw.contains(pendingTarget))) ? pendingTarget : retarget(raw);
    var implicit = !pendingTarget && e.detail === 0 && (MT.describe.role(target) === 'submit' || MT.describe.role(target) === 'button');
    pendingTarget = null;
    if (e.button !== undefined && e.button !== 0) return;
    if (implicit && MT.typing.recentEnter()) return; // the browser's implicit form submission after Enter, already recorded as the Enter
    if (MT.modes.current() === 'assert') { MT.assert.fromClick(target, e); e.preventDefault(); e.stopPropagation(); return; }
    if (MT.modes.current() === 'hover') { MT.hover.record(target); MT.modes.set('record'); e.preventDefault(); e.stopPropagation(); return; }
    if (widgetHandles('click', e, target)) return;
    recordClick(target, e);
  }

  function recordClick(target, e) {
    var role = MT.describe.role(target);
    // Labels: clicking a label of a checkable input toggles it (recorded on change);
    // a label of anything else only focuses -> nothing.
    if (role === 'label') {
      var control = target.control || (target.htmlFor ? document.getElementById(target.htmlFor) : target.querySelector('input, select, textarea'));
      if (control && MT.util.isCheckable(control)) { MT.checkables.expectChange(control, true); return; }
      return;
    }
    if (role === 'checkbox' || role === 'radio') { MT.checkables.expectChange(target, false); return; }
    if (role === 'text' || role === 'select' || role === 'file') return; // focus only
    if (target.tagName === 'TEXTAREA') return;
    if (target === document.body || target === document.documentElement) return; // a click on nothing
    if (dedupe('click:' + MT.util.fingerprint(target) + ':' + MT.util.textOf(target))) return;
    var kinds = (role === 'link') ? ['link_or_button', 'link'] : ((role === 'button' || role === 'submit') ? ['link_or_button', 'button'] : []);
    var event = {
      kind: 'click', role: role, target: MT.describe.describe(target),
      candidates: MT.locators.candidates(target, kinds), modal: MT.locators.currentModal(target),
      effects: { window_opened: target.tagName === 'A' && target.getAttribute('target') === '_blank' }
    };
    MT.effects.markUserEvent(event);
    MT.dialogs.noteTrigger(event, target);
    MT.transport.send(event);
    setTimeout(function () { if (MT.windows.consumeOpened()) { MT.transport.send({ kind: 'effect', trigger_event_id: event.id, effect: 'window_opened' }); } }, 50);
    if (!MT.util.isVisible(target)) {
      // Clicked during a fade-in (Bootstrap modal/dropdown at opacity 0): Capybara would
      // not see it yet. Recompute once the transition is over and update the event.
      setTimeout(function () {
        if (!document.contains(target) || !MT.util.isVisible(target)) return;
        MT.transport.send({ kind: 'candidates_update', event_id: event.id, candidates: MT.locators.candidates(target, kinds), modal: MT.locators.currentModal(target) });
      }, 300);
    }
  }

  function onChange(e) {
    if (!e.isTrusted || !active()) return;
    var target = eventTarget(e);
    if (isOurs(target)) return;
    if (widgetHandles('change', e, target)) return;
    if (MT.util.isCheckable(target)) { MT.checkables.changed(target); return; }
    if (target.tagName === 'SELECT') { MT.selects.changed(target); return; }
    if (target.tagName === 'INPUT' && target.type === 'file') { MT.files.changed(target); return; }
    if (MT.util.isTextLike(target)) { MT.typing.commit(target, 'change'); return; }
  }

  function onInput(e) {
    if (!e.isTrusted || !active()) return;
    var target = eventTarget(e);
    if (isOurs(target)) return;
    if (widgetHandles('input', e, target)) return;
    if (MT.util.isTextLike(target)) MT.typing.touched(target);
  }

  function onKeyDown(e) {
    if (!e.isTrusted) return;
    if (MT.toolbar && MT.toolbar.shortcut(e)) return;
    if (!active()) return;
    var target = eventTarget(e);
    if (isOurs(target)) return;
    if (widgetHandles('keydown', e, target)) return;
    if (e.key === 'Enter' && target.tagName === 'INPUT' && MT.util.isTextLike(target)) MT.typing.enter(target, e);
  }

  function onFocusOut(e) {
    if (!active()) return;
    var target = eventTarget(e);
    if (MT.util.isTextLike(target)) MT.typing.commit(target, 'blur');
  }

  function onSubmit(e) {
    if (!e.isTrusted || !active()) return;
    MT.typing.commitAll('submit');
  }

  // Listeners go on `window` in the capture phase: Bootstrap 5 registers its
  // delegated data-api handlers on `document` with useCapture=true, and
  // listeners on the same node fire in registration order, so a modal's
  // dismiss or a dropdown toggle would otherwise run before the recorder sees
  // the click. The window is visited first in the capture phase.
  function install() {
    window.addEventListener('pointerdown', onPointerDown, true);
    window.addEventListener('mousedown', function (e) { if (!window.PointerEvent) onPointerDown(e); }, true);
    window.addEventListener('click', onClick, true);
    window.addEventListener('change', onChange, true);
    window.addEventListener('input', onInput, true);
    window.addEventListener('keydown', onKeyDown, true);
    window.addEventListener('focusout', onFocusOut, true);
    window.addEventListener('submit', onSubmit, true);
    window.addEventListener('pagehide', function () { MT.typing.commitAll('unload'); }, true);
  }

  return { install: install, registerWidget: registerWidget, retarget: retarget, isOurs: isOurs, dedupe: dedupe, pause: function () { paused = true; }, resume: function () { paused = false; }, paused: function () { return paused; }, recordClick: recordClick };
})();
