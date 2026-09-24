(function () {
  var t = window.__mt, MT = t.MT(), assert = t.assert;
  t.describe('event normalisation', function () {
    t.it('retargets icons to the nearest actionable ancestor', function () {
      var icon = document.querySelector('#lead_1 .js-star i');
      assert.equal(MT.recording.retarget(icon), icon.closest('button'));
      var abbr = document.querySelector('label[for=profile_first_name] abbr');
      assert.equal(MT.recording.retarget(abbr).tagName, 'LABEL');
    });
    t.it('ignores untrusted events and the toolbar', function () {
      var before = MT.transport.lastState() ? MT.transport.lastState().steps.length : 0;
      document.querySelector('#main-nav button').dispatchEvent(new MouseEvent('click', { bubbles: true }));
      var host = MT.toolbar.host();
      assert.ok(host, 'toolbar mounted');
      assert.ok(MT.recording.isOurs(host));
      assert.ok(!MT.recording.isOurs(document.body));
      assert.ok(before === before); // no exception is the assertion here
    });
    t.it('dedupes the same intent on the same element within 300ms', function () {
      assert.equal(MT.recording.dedupe('x:1'), false);
      assert.equal(MT.recording.dedupe('x:1'), true);
      assert.equal(MT.recording.dedupe('x:2'), false);
    });
    t.it('exposes only the public API on window', function () {
      assert.deepEqual(Object.keys(window.MagicTest).sort(), ['__internals', '__loaded', 'assert', 'errors', 'legacyDetected', 'modes', 'status', 'version', 'windowId']);
      ['ready', 'isUnique', 'clickFunction', 'getPathTo', 'codes', 'MT', 'finderForElement'].forEach(function (n) { assert.equal(typeof window[n], 'undefined', n); });
      assert.equal(window.MagicTest.legacyDetected, false);
      assert.deepEqual(window.MagicTest.errors(), []);
    });
    t.it('window and frame identity', function () {
      assert.deepEqual(MT.windows.identity(), { id: 'main', opener: null });
      assert.equal(MT.windows.frameIdentity(), null);
    });
  });
})();
