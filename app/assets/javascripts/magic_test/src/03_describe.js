// Element descriptor sent with every event: raw facts only, no Ruby.
MT.describe = (function () {
  function role(node) {
    if (!node) return 'other';
    var tag = node.tagName;
    if (tag === 'A' && node.hasAttribute('href')) return 'link';
    if (tag === 'BUTTON') return node.type === 'submit' ? 'submit' : 'button';
    if (tag === 'INPUT' && node.type === 'submit') return 'submit';
    if (tag === 'INPUT' && ['button', 'image', 'reset'].indexOf(node.type) !== -1) return 'button';
    if (tag === 'INPUT' && node.type === 'checkbox') return 'checkbox';
    if (tag === 'INPUT' && node.type === 'radio') return 'radio';
    if (tag === 'INPUT' && node.type === 'file') return 'file';
    if (tag === 'SELECT') return 'select';
    if (MT.util.isTextLike(node)) return 'text';
    if (tag === 'LABEL') return 'label';
    if (tag === 'TRIX-EDITOR') return 'trix';
    if (node.getAttribute('role') === 'button') return 'button';
    if (tag === 'SUMMARY') return 'button';
    return 'other';
  }

  function dataAttributes(node) {
    var out = {};
    if (!node || !node.attributes) return out;
    for (var i = 0; i < node.attributes.length; i++) {
      var a = node.attributes[i];
      if (a.name.indexOf('data-') === 0 && a.name !== 'data-magic-test') out[a.name] = a.value;
    }
    return out;
  }

  function describe(node) {
    if (!node || node.nodeType !== 1) return null;
    var r = role(node);
    return {
      tag: node.tagName.toLowerCase(),
      type: node.type || null,
      role: r,
      id: node.id || null,
      name: node.name || null,
      classes: Array.from(node.classList || []),
      text: MT.util.textOf(node),
      own_text: MT.util.ownText(node),
      label: MT.util.labelTextFor(node),
      placeholder: node.placeholder || null,
      aria_label: node.getAttribute('aria-label'),
      title: node.getAttribute('title'),
      value: (node.tagName === 'INPUT' && ['submit', 'button', 'reset'].indexOf(node.type) !== -1) ? node.value : null,
      href: node.getAttribute('href'),
      data: dataAttributes(node),
      hidden: MT.util.isVisuallyHidden(node),
      disabled: MT.util.isDisabled(node),
      checked: node.checked === true,
      fingerprint: MT.util.fingerprint(node),
      html_id_dynamic: node.id ? MT.dynamic.isDynamic(node.id) : false
    };
  }

  return { describe: describe, role: role };
})();
