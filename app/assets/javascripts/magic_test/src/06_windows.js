// Window and frame identity: which browser window and same-origin iframe an
// event happened in, so Ruby can wrap steps in within_window / within_frame.
MT.windows = (function () {
  var id = null;

  function identity() {
    if (!id) {
      try {
        if (window.top !== window) {
          id = (window.top.MagicTest && window.top.MagicTest.windowId && window.top.MagicTest.windowId()) || 'main';
        } else if (window.opener && !window.opener.closed && window.opener.MagicTest) {
          id = window.name && window.name.indexOf('magic-test-w') === 0 ? window.name : ('magic-test-w' + Date.now().toString(36));
          window.name = id;
        } else if (window.name && window.name.indexOf('magic-test-w') === 0) {
          id = window.name;
        } else {
          id = 'main';
        }
      } catch (e) { id = 'main'; }
    }
    return { id: id, opener: (id !== 'main') ? 'main' : null };
  }

  // Locator of the iframe this document lives in, computed in the parent.
  function frameIdentity() {
    try {
      if (window.top === window) return null;
      var el = window.frameElement;
      if (!el) return null;
      var name = el.getAttribute('name');
      var fid = el.getAttribute('id');
      var locator = (name && !MT.dynamic.isDynamic(name)) ? name : ((fid && !MT.dynamic.isDynamic(fid)) ? fid : null);
      var css = null;
      if (!locator) {
        var classes = MT.dynamic.semanticClasses(el);
        css = classes.length ? 'iframe.' + classes.map(MT.util.cssEscape).join('.') : 'iframe[src="' + el.getAttribute('src') + '"]';
      }
      return { locator: locator, css: css };
    } catch (e) { return null; }
  }

  function isChildWindow() {
    return identity().id !== 'main';
  }

  // Patch window.open so a click that opens a window is marked.
  var opened = false;
  function install() {
    var original = window.open;
    window.open = function () {
      opened = true;
      setTimeout(function () { opened = false; }, 1000);
      return original.apply(window, arguments);
    };
  }

  function consumeOpened() {
    var v = opened;
    opened = false;
    return v;
  }

  return { identity: identity, frameIdentity: frameIdentity, isChildWindow: isChildWindow, install: install, consumeOpened: consumeOpened, windowId: function () { return identity().id; } };
})();
