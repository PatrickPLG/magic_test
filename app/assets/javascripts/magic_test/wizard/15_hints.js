// "?" hints (1.2 §6): one popover at a time, on hover and on keyboard focus,
// closed by Esc, blur or mouseleave; aria-describedby links button and text.
// Texts come from config/hints.yml through the catalogue payload.
W.hints = (function () {
  var h = W.h;
  var open = null;
  var seq = 0;

  function data(key) {
    var parts = key.split('.');
    var all = (W.state.catalogue && W.state.catalogue.hints) || {};
    return parts[0] === 'wizard' ? all[parts[1]] : (all[parts[0]] && all[parts[0]][parts[1]]);
  }

  function close() {
    if (!open) return;
    open.pop.remove();
    open.btn.removeAttribute('aria-describedby');
    open = null;
  }

  function show(btn, key) {
    var d = data(key);
    if (!d) return;
    close();
    var id = 'hint-' + (++seq);
    var pop = h('div', { class: 'popover', role: 'tooltip', id: id }, [
      h('div', { text: d.text }),
      d.when ? h('div', { class: 'when', text: 'When: ' + d.when }) : null,
      d.example ? h('pre', { text: String(d.example).replace(/\s+$/, '') }) : null
    ]);
    document.body.appendChild(pop);
    var r = btn.getBoundingClientRect();
    var top = r.bottom + 6, left = Math.min(r.left, window.innerWidth - 380);
    if (top + pop.offsetHeight > window.innerHeight) top = Math.max(6, r.top - pop.offsetHeight - 6);
    pop.style.top = top + 'px';
    pop.style.left = Math.max(6, left) + 'px';
    btn.setAttribute('aria-describedby', id);
    open = { pop: pop, btn: btn, key: key };
  }

  // The "?" button for a hint key such as 'wizard.trait'.
  function hint(key, label) {
    var btn = h('button', { type: 'button', class: 'hint', 'data-hint': key, 'aria-label': label || ('What is this? ' + key.split('.')[1].replace(/_/g, ' ')), text: '?' });
    btn.addEventListener('mouseenter', function () { show(btn, key); });
    btn.addEventListener('focus', function () { show(btn, key); });
    btn.addEventListener('mouseleave', function () { if (document.activeElement !== btn) close(); });
    btn.addEventListener('blur', close);
    btn.addEventListener('click', function (e) { e.preventDefault(); if (open && open.btn === btn) close(); else show(btn, key); });
    return btn;
  }

  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') close(); });

  return { hint: hint, close: close, current: function () { return open && open.key; } };
})();
