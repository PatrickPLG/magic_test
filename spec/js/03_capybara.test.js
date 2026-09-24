(function () {
  var t = window.__mt, MT = t.MT(), assert = t.assert;
  t.describe('capybara xpath counts', function () {
    t.it('has templates for every selector kind', function () {
      ['link_or_button', 'link', 'button', 'fillable_field', 'select', 'checkbox', 'radio_button', 'field', 'file_field'].forEach(function (k) {
        assert.ok(MT.config.xpath[k] && MT.config.xpath[k].exact && MT.config.xpath[k].partial, k);
      });
    });
    t.it('escapes quotes in locators', function () {
      assert.equal(MT.capybara.xpathLiteral("Studiz' vilkår"), '"Studiz\' vilkår"');
      assert.equal(MT.capybara.xpathLiteral('Se "Fest"'), "'Se \"Fest\"'");
      assert.match(MT.capybara.xpathLiteral('a\'b"c'), /^concat\(/);
      assert.equal(MT.capybara.count('link_or_button', "Læs Studiz' vilkår", document).unique, true);
      assert.equal(MT.capybara.count('link_or_button', 'Se "Fest" arrangementer', document).unique, true);
    });
    t.it('applies smart matching: exact before partial', function () {
      var gem = MT.capybara.count('link_or_button', 'Gem', document);
      assert.equal(gem.exact, 1); assert.equal(gem.partial, 2); assert.equal(gem.unique, true);
      var rab = MT.capybara.count('link_or_button', 'Rabatter', document);
      assert.equal(rab.exact, 2); assert.equal(rab.unique, false);
      var arr = MT.capybara.count('link_or_button', 'arrangement', document);
      assert.equal(arr.exact, 0); assert.equal(arr.partial, 3); assert.equal(arr.unique, false);
    });
    t.it('ignores hidden and disabled elements like Capybara', function () {
      assert.equal(MT.capybara.count('link', 'Skjult link', document).partial, 0);
      assert.equal(MT.capybara.count('button', 'Deaktiveret', document).partial, 0);
      assert.equal(MT.capybara.count('fillable_field', 'profile[locked]', document).partial, 0);
      assert.equal(MT.capybara.count('checkbox', 'Nyhedsbrev', document).partial, 1);
      // `.visually-hidden` is clipped, not display:none, so Capybara/Cuprite treat it as visible.
      assert.equal(MT.capybara.count('radio_button', 'Kvinde', document).partial, 1);
      assert.equal(MT.capybara.count('radio_button', 'Kvinde', document, null, { visibleAll: true }).partial, 1);
    });
    t.it('matches fields by label, id, name and placeholder', function () {
      ['Fornavn', '* Fornavn', 'profile_first_name', 'profile[first_name]', 'Dit fornavn'].forEach(function (loc) {
        assert.equal(MT.capybara.count('fillable_field', loc, document).unique, true, loc);
      });
      assert.equal(MT.capybara.count('select', 'Land', document).unique, true);
      assert.equal(MT.capybara.count('select', 'Kategori', document, null, { visibleAll: true }).unique, true);
    });
    t.it('counts inside a scope', function () {
      var row = document.querySelector('#lead_2');
      assert.equal(MT.capybara.count('link_or_button', 'Rediger', document).partial, 3);
      assert.equal(MT.capybara.count('link_or_button', 'Rediger', row).unique, true);
    });
  });
})();
