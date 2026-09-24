// Checkboxes and radios (native or behind Studiz `.checkmark` labels):
// recorded from the resulting checked state on `change`.
MT.checkables = (function () {
  var expected = new Map();

  function expectChange(control, viaLabel) {
    expected.set(control, { at: Date.now(), viaLabel: viaLabel });
  }

  function changed(control) {
    var info = expected.get(control);
    expected.delete(control);
    var kind = control.type === 'radio' ? 'choose' : 'check';
    var hidden = MT.util.isVisuallyHidden(control);
    var event = {
      kind: kind, target: MT.describe.describe(control), checked: control.checked, hidden: hidden,
      via_label: !!(info && info.viaLabel),
      candidates: MT.locators.candidates(control, [control.type === 'radio' ? 'radio_button' : 'checkbox'], { visibleAll: hidden }),
      modal: MT.locators.currentModal(control)
    };
    if (MT.recording.dedupe(kind + ':' + MT.util.fingerprint(control) + ':' + control.checked)) return;
    MT.effects.markUserEvent(event);
    MT.transport.send(event);
  }

  return { expectChange: expectChange, changed: changed };
})();
