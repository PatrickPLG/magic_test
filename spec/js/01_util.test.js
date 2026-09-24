(function () {
  var t = window.__mt, MT = t.MT(), assert = t.assert;
  t.describe('util', function () {
    t.it('normalizes text like Capybara', function () {
      assert.equal(MT.util.normalizeText('  Gem \n arrangement  '), 'Gem arrangement');
      assert.equal(MT.util.textOf(document.querySelector('a[title="Alle arrangementer"]')), 'Arrangementer');
    });
    t.it('ownText skips badges and icons', function () {
      var link = Array.from(document.querySelectorAll('#main-nav a')).find(function (a) { return a.textContent.indexOf('Beskeder') !== -1; });
      assert.equal(MT.util.ownText(link), 'Beskeder');
      assert.equal(MT.util.textOf(link), 'Beskeder 3');
    });
    t.it('visibility follows Cuprite (display none up the tree)', function () {
      assert.ok(MT.util.isVisible(document.querySelector('#page-title')));
      assert.ok(!MT.util.isVisible(document.querySelector('a[href="/hidden"]')));
      assert.ok(MT.util.isVisuallyHidden(document.querySelector('#profile_gender_female')));
      assert.ok(!MT.util.isVisuallyHidden(document.querySelector('#profile_newsletter')));
    });
    t.it('disabled follows Capybara (fieldset)', function () {
      assert.ok(MT.util.isDisabled(document.querySelector('#profile_locked')));
      assert.ok(MT.util.isDisabled(document.querySelector('button.btn-secondary')));
      assert.ok(!MT.util.isDisabled(document.querySelector('#profile_first_name')));
    });
    t.it('finds labels including the required mark and wrapping labels', function () {
      assert.equal(MT.util.labelTextFor(document.querySelector('#profile_first_name')), '* Fornavn');
      assert.equal(MT.util.labelTextFor(document.querySelector('#profile_gender_female')), 'Kvinde');
      assert.equal(MT.util.labelTextFor(document.querySelector('#profile_terms')), "Jeg accepterer Studiz' vilkår");
    });
    t.it('classifies roles', function () {
      assert.equal(MT.describe.role(document.querySelector('#main-nav a')), 'link');
      assert.equal(MT.describe.role(document.querySelector('button[type=submit]')), 'submit');
      assert.equal(MT.describe.role(document.querySelector('#profile_newsletter')), 'checkbox');
      assert.equal(MT.describe.role(document.querySelector('#profile_country')), 'select');
      assert.equal(MT.describe.role(document.querySelector('trix-editor')), 'trix');
      assert.equal(MT.describe.role(document.querySelector('#profile_avatar')), 'file');
    });
  });
})();
