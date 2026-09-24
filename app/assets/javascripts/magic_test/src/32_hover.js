// Explicit hover recording (toolbar action): the next click target is
// recorded as `find(...).hover`; nothing is observed on ordinary mouse moves.
// The visible-effect check (a dropdown/menu opened) comes from the
// hover-feature branch and only affects the confidence badge.
MT.hover = (function () {
  function record(target) {
    MT.typing.commitAll('hover');
    var trigger = target.closest('[data-bs-toggle="dropdown"], [aria-haspopup], .dropdown-toggle, li') || target;
    var before = state(trigger);
    var event = { kind: 'hover', target: MT.describe.describe(target), candidates: MT.locators.candidates(target, ['link', 'button', 'link_or_button']), modal: MT.locators.currentModal(target), effect: false };
    try { target.dispatchEvent(new MouseEvent('mouseover', { bubbles: true })); } catch (e) { /* ignore */ }
    setTimeout(function () {
      event.effect = state(trigger) !== before || !!document.querySelector('.dropdown-menu.show, .show > .dropdown-menu, [aria-expanded="true"]');
      MT.transport.send(event);
      MT.toolbar && MT.toolbar.notify('Hover recorded' + (event.effect ? '' : ' (no visible effect)'));
    }, 150);
  }

  function state(el) {
    return (el.getAttribute('aria-expanded') || '') + ':' + (el.classList.contains('show') ? 'show' : '');
  }

  var lastPointer = { x: 0, y: 0 };
  window.addEventListener('mousemove', function (e) { lastPointer = { x: e.clientX, y: e.clientY }; }, { capture: true, passive: true });

  // Alt+Shift+H: record a hover on whatever is under the mouse right now.
  function recordAtPointer() {
    var el = document.elementFromPoint(lastPointer.x, lastPointer.y);
    if (!el || MT.recording.isOurs(el)) { MT.toolbar && MT.toolbar.notify('Move the mouse over an element, then press Alt+Shift+H'); return null; }
    record(MT.recording.retarget(el));
    return el;
  }

  return { record: record, recordAtPointer: recordAtPointer };
})();
