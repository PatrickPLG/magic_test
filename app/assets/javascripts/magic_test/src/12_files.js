// File inputs. The recorder cannot know the local path the person picked; it
// records the file name(s) and Ruby maps them to spec/fixtures/files.
MT.files = (function () {
  function changed(input) {
    var names = Array.from(input.files || []).map(function (f) { return f.name; });
    if (!names.length) return;
    var hidden = MT.util.isVisuallyHidden(input);
    var event = {
      kind: 'file', target: MT.describe.describe(input), files: names, hidden: hidden,
      cropper: !!(input.classList.contains('cover-image-upload') || input.getAttribute('data-cropper-target')),
      candidates: MT.locators.candidates(input, ['file_field'], { visibleAll: true }), modal: MT.locators.currentModal(input)
    };
    MT.effects.markUserEvent(event);
    MT.transport.send(event);
  }

  return { changed: changed };
})();
