(function () {
  var t = window.__mt, MT = t.MT(), assert = t.assert;
  t.describe('dynamic values', function () {
    t.it('rejects record ids known to the session', function () {
      var id = document.querySelector('[data-discount-id]').getAttribute('data-discount-id');
      assert.includes(MT.config.known_ids, id, 'session knows the discount id from the page params');
      assert.ok(MT.dynamic.isDynamic('discount-card-' + id));
      assert.equal(MT.dynamic.stableId(document.querySelector('[data-discount-id]')), null);
      assert.equal(MT.dynamic.stableId(document.querySelector('#discount-card-new')), 'discount-card-new');
    });
    t.it('rejects timestamps, trix counters, nested indices and chosen containers', function () {
      assert.ok(MT.dynamic.isDynamic('events_event_ticket_types_attributes_1695551234567_name'));
      assert.ok(MT.dynamic.isDynamic('trix_input_3'));
      assert.ok(MT.dynamic.isDynamic('events_event[ticket_types_attributes][0][name]'));
      assert.equal(MT.dynamic.stableId({ id: 'profile_category_chosen' }), null);
      assert.equal(MT.dynamic.stableId({ id: 'events_event_description' }), 'events_event_description');
    });
    t.it('filters Bootstrap utilities but keeps semantic classes', function () {
      var card = document.querySelector('#discount-card-new');
      assert.deepEqual(MT.dynamic.semanticClasses(card), ['card', 'discount-card']);
      assert.deepEqual(MT.dynamic.semanticClasses(document.querySelector('.js-star')), ['btn', 'js-star']);
      assert.ok(MT.dynamic.isBootstrapUtility('mt-3'));
      assert.ok(MT.dynamic.isBootstrapUtility('col-md-6'));
      assert.ok(!MT.dynamic.isBootstrapUtility('card-title'));
    });
  });
})();
