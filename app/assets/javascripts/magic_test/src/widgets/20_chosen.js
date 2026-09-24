// Chosen 1.8.7: a pick (with any search text folded in) or a deselect on the
// underlying <select>. Opening the dropdown alone is not a step.
MT.widgets = MT.widgets || {};
MT.widgets.chosen = (function () {
  var searchText = new WeakMap();

  function underlyingSelect(container) {
    if (!container) return null;
    var id = container.id;
    if (id && /_chosen$/.test(id)) {
      var raw = id.replace(/_chosen$/, '');
      var el = document.getElementById(raw) || Array.from(document.querySelectorAll('select')).find(function (s) { return s.id && s.id.replace(/[^\w]/g, '_') === raw; });
      if (el) return el;
    }
    var prev = container.previousElementSibling;
    return (prev && prev.tagName === 'SELECT') ? prev : null;
  }

  function candidates(select) {
    return MT.locators.candidates(select, ['select'], { visibleAll: true });
  }

  function emit(select, action, option, container) {
    var event = {
      kind: 'chosen', action: action, option: option, search: searchText.get(container) || null,
      target: MT.describe.describe(select), candidates: candidates(select), modal: MT.locators.currentModal(select)
    };
    searchText.delete(container);
    MT.effects.markUserEvent(event);
    MT.transport.send(event);
  }

  var pendingPick = null; // { container, text, at } captured at pointerdown

  var widget = {
    pointerdown: function (e, target) {
      var li = target.closest && target.closest('.chosen-container ul.chosen-results li.active-result');
      if (li) pendingPick = { container: li.closest('.chosen-container'), text: MT.util.normalizeText(li.textContent), at: Date.now() };
      return false;
    },
    click: function (e, target) {
      var container = (target.closest && target.closest('.chosen-container')) || (pendingPick && Date.now() - pendingPick.at < 1500 ? pendingPick.container : null);
      if (!container) return false;
      var select = underlyingSelect(container);
      if (!select) return true; // Chosen without a mappable select: nothing trustworthy to record
      var result = target.closest('ul.chosen-results li');
      if (pendingPick && Date.now() - pendingPick.at < 1500 && pendingPick.container === container) {
        // pendingPick wins: Chosen selects on mouseup and re-classes/re-renders the
        // result before the click arrives (`active-result` becomes `result-selected`).
        var picked = pendingPick; pendingPick = null;
        emit(select, 'select', picked.text, container);
        return true;
      }
      pendingPick = null;
      var close = target.closest('a.search-choice-close');
      if (close) {
        var choice = close.closest('li.search-choice');
        var text = choice ? MT.util.textOf(choice.querySelector('span') || choice) : '';
        if (text) emit(select, 'unselect', text, container);
        return true;
      }
      if (result && result.classList.contains('active-result')) {
        emit(select, 'select', MT.util.normalizeText(result.textContent), container);
        return true;
      }
      return true; // open/close clicks are folded into the pick
    },
    input: function (e, target) {
      if (!target.classList || !target.classList.contains('chosen-search-input')) return false;
      var container = target.closest('.chosen-container');
      if (container) searchText.set(container, target.value);
      return true;
    },
    change: function (e, target) {
      return !!(target.classList && target.classList.contains('chosen-search-input'));
    },
    keydown: function (e, target) {
      if (!target.classList || !target.classList.contains('chosen-search-input')) return false;
      if (e.key !== 'Enter') return true;
      // Enter picks the highlighted result.
      var container = target.closest('.chosen-container');
      var highlighted = container && container.querySelector('ul.chosen-results li.highlighted');
      var select = underlyingSelect(container);
      if (highlighted && select) emit(select, 'select', MT.util.normalizeText(highlighted.textContent), container);
      return true;
    }
  };

  MT.recording.registerWidget(widget);
  return { underlyingSelect: underlyingSelect };
})();
