// Trix 1.2: the editor's final text/HTML on blur/trix-change, located by its
// label or the <trix-editor> id, never by the hidden `trix_input_N`.
MT.widgets.trix = (function () {
  var dirty = new Set();

  function editorFor(node) {
    return node && node.closest ? node.closest('trix-editor') : null;
  }

  function emit(editor) {
    if (!dirty.has(editor)) return;
    dirty.delete(editor);
    var hidden = editor.getAttribute('input') ? document.getElementById(editor.getAttribute('input')) : null;
    var event = {
      kind: 'trix', target: MT.describe.describe(editor),
      value_text: MT.util.normalizeText(editor.editor ? editor.editor.getDocument().toString() : editor.textContent),
      value_html: hidden ? hidden.value : editor.innerHTML, input_id: editor.getAttribute('input'),
      candidates: MT.locators.candidates(editor, ['trix']), modal: MT.locators.currentModal(editor)
    };
    MT.transport.send(event);
  }

  function install() {
    document.addEventListener('trix-change', function (e) { if (MT.session && MT.session.recording()) dirty.add(e.target); }, true);
    document.addEventListener('trix-blur', function (e) { emit(e.target); }, true);
    document.addEventListener('focusout', function (e) { var ed = editorFor(e.target); if (ed) emit(ed); }, true);
    document.addEventListener('submit', function () { Array.from(dirty).forEach(emit); }, true);
    window.addEventListener('pagehide', function () { Array.from(dirty).forEach(emit); }, true);
  }

  var widget = {
    click: function (e, target) { return !!editorFor(target) || !!(target.closest && target.closest('trix-toolbar')); },
    input: function (e, target) { var ed = editorFor(target); if (ed) { dirty.add(ed); return true; } return false; },
    change: function (e, target) { return !!editorFor(target); },
    keydown: function (e, target) { return !!editorFor(target); }
  };

  MT.recording.registerWidget(widget);
  return { install: install, emit: emit };
})();
