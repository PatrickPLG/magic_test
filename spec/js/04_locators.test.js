(function () {
  var t = window.__mt, MT = t.MT(), assert = t.assert;
  function best(cands, pred) { return cands.filter(pred); }
  t.describe('locator candidates', function () {
    t.it('proposes own text before full text for a link with a badge', function () {
      var link = Array.from(document.querySelectorAll('#main-nav a')).find(function (a) { return a.textContent.indexOf('Beskeder') !== -1; });
      var c = MT.locators.candidates(link, ['link_or_button']);
      assert.equal(c[0].by, 'own_text'); assert.equal(c[0].locator, 'Beskeder'); assert.equal(c[0].unique, true);
    });
    t.it('offers title and css for an icon-only link', function () {
      var link = document.querySelector('a.js-icon-only');
      var c = MT.locators.candidates(link, ['link_or_button']);
      assert.ok(best(c, function (x) { return x.by === 'title' && x.locator === 'Indstillinger' && x.unique; }).length === 1);
      assert.ok(best(c, function (x) { return x.kind === 'css' && x.locator === 'a.js-icon-only' && x.unique; }).length === 1);
    });
    t.it('scopes an ambiguous row action to its row by unique text', function () {
      var edit = document.querySelector('#lead_2 a');
      var c = MT.locators.candidates(edit, ['link_or_button']);
      var global = best(c, function (x) { return x.by === 'text' && !x.scope; })[0];
      assert.equal(global.unique, false);
      var scoped = best(c, function (x) { return x.by === 'text' && x.scope && x.scope.kind === 'row'; })[0];
      assert.ok(scoped, 'row-scoped candidate');
      assert.equal(scoped.scope.css, 'tr'); assert.equal(scoped.scope.text, 'Lead 2'); assert.equal(scoped.unique, true);
    });
    t.it('never proposes ids embedding record ids, timestamps or trix counters', function () {
      var card = document.querySelector('[data-discount-id]');
      MT.locators.cssCandidates(card).forEach(function (x) { assert.ok(!/discount-card-\d/.test(x.locator), x.locator); });
      var nested = document.querySelector('input[name*="1695551234567"]');
      MT.locators.candidates(nested, ['fillable_field']).forEach(function (x) { assert.ok(!/1695551234567/.test(x.locator), x.locator); });
      var trix = document.querySelector('trix-editor');
      MT.locators.candidates(trix, ['trix']).forEach(function (x) { assert.ok(!/trix_input/.test(x.locator), x.locator); });
      assert.ok(MT.locators.candidates(trix, ['trix']).some(function (x) { return x.by === 'id' && x.locator === 'events_event_description' && x.unique; }));
    });
    t.it('positional selectors only inside a stable scope and never absolute', function () {
      var star = document.querySelector('#lead_3 .js-star');
      var c = MT.locators.cssCandidates(star);
      var pos = c.filter(function (x) { return x.kind === 'positional'; })[0];
      assert.ok(pos, 'has a positional fallback');
      assert.ok(pos.scope, 'positional is scoped');
      assert.ok(!/^\/html/i.test(pos.locator));
    });
    t.it('reports the open modal as the current scope', function () {
      var modal = document.querySelector('#ajax-modal');
      modal.classList.add('show');
      modal.style.display = 'block';
      try {
        assert.equal(MT.locators.currentModal(modal.querySelector('button')), '#ajax-modal');
        assert.equal(MT.locators.currentModal(document.querySelector('#page-title')), null);
        var c = MT.locators.candidates(modal.querySelector('button'), ['link_or_button']);
        var scoped = c.filter(function (x) { return x.by === 'text' && x.scope && x.scope.kind === 'modal'; })[0];
        assert.ok(scoped && scoped.unique, 'Gem is unique inside the modal');
      } finally { modal.classList.remove('show'); modal.style.display = ''; }
    });
  });
})();
