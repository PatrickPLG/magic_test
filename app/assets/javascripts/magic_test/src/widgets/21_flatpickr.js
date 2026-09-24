// flatpickr 4.6.9: the resulting input value is the step, not calendar clicks.
MT.widgets.flatpickr = (function () {
  function instanceFor(node) {
    if (!node) return null;
    if (node._flatpickr) return node._flatpickr;
    var wrapper = node.closest && node.closest('.flatpickr-wrapper, [data-wrap], .js-datetimepicker-field, .js-datepicker-birthday-field');
    return wrapper && wrapper._flatpickr ? wrapper._flatpickr : null;
  }

  function inputFor(fp) {
    return fp && (fp._input || fp.input);
  }

  function emit(fp) {
    var input = inputFor(fp);
    if (!input) return;
    var value = input.value;
    if (input.__mtLastFlatpickr === value) return;
    input.__mtLastFlatpickr = value;
    var event = {
      kind: 'flatpickr', value: value, target: MT.describe.describe(input),
      candidates: MT.locators.candidates(input, ['fillable_field']), modal: MT.locators.currentModal(input)
    };
    MT.effects.markUserEvent(event);
    MT.transport.send(event);
  }

  function hook(fp) {
    if (!fp || fp.__mtHooked) return;
    fp.__mtHooked = true;
    var onChange = function () { if (MT.session && MT.session.recording()) setTimeout(function () { emit(fp); }, 0); };
    fp.config.onChange = (fp.config.onChange || []).concat([onChange]);
    fp.config.onClose = (fp.config.onClose || []).concat([onChange]);
  }

  var widget = {
    pointerdown: function (e, target) {
      var calendar = target.closest && target.closest('.flatpickr-calendar');
      if (calendar) return true;
      var fp = instanceFor(target);
      if (fp) hook(fp);
      return false;
    },
    click: function (e, target) {
      if (target.closest && target.closest('.flatpickr-calendar')) return true; // calendar clicks are not steps
      if (target.hasAttribute && (target.hasAttribute('data-toggle') || target.hasAttribute('data-input')) && instanceFor(target)) return true;
      return false;
    },
    input: function (e, target) {
      var fp = instanceFor(target);
      if (!fp) return false;
      hook(fp);
      return true; // typed dates (allowInput) are emitted by onChange/onClose
    },
    change: function (e, target) {
      var fp = instanceFor(target);
      if (!fp) return false;
      hook(fp);
      setTimeout(function () { emit(fp); }, 0);
      return true;
    },
    keydown: function (e, target) {
      return !!(target.closest && target.closest('.flatpickr-calendar'));
    }
  };

  function installAll() {
    document.querySelectorAll('input').forEach(function (i) { var fp = instanceFor(i); if (fp) hook(fp); });
  }

  MT.recording.registerWidget(widget);
  return { instanceFor: instanceFor, installAll: installAll, hook: hook };
})();
