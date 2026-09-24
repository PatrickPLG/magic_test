// Native <select> (single and multiple): diff of selected option texts.
MT.selects = (function () {
  var previous = new WeakMap();

  function selectedTexts(select) {
    return Array.from(select.selectedOptions || []).map(function (o) { return MT.util.normalizeText(o.textContent); });
  }

  function remember(select) {
    if (!previous.has(select)) previous.set(select, selectedTexts(select));
  }

  function changed(select) {
    if (select.classList.contains('chosen-select') && select.nextElementSibling && select.nextElementSibling.classList.contains('chosen-container')) return; // Chosen widget handles it
    var before = previous.get(select) || [];
    var now = selectedTexts(select);
    previous.set(select, now);
    var added = now.filter(function (t) { return before.indexOf(t) === -1; });
    var removed = before.filter(function (t) { return now.indexOf(t) === -1; });
    if (!added.length && !removed.length && !select.multiple) added = now;
    var event = {
      kind: 'select', target: MT.describe.describe(select), selected: now, added: added, removed: removed, multiple: !!select.multiple,
      candidates: MT.locators.candidates(select, ['select']), modal: MT.locators.currentModal(select)
    };
    MT.effects.markUserEvent(event);
    MT.transport.send(event);
  }

  function install() {
    window.addEventListener('focusin', function (e) { var t = e.target; if (t && t.tagName === 'SELECT') remember(t); }, true);
    window.addEventListener('pointerdown', function (e) { var t = e.target && e.target.closest && e.target.closest('select'); if (t) remember(t); }, true);
  }

  return { changed: changed, install: install, remember: remember };
})();
