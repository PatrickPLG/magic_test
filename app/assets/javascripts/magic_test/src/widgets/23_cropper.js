// Cropper.js flow behind Studiz's cover image upload: the apply click closes
// the loop started by the file change (Ruby folds both into magic_attach_image).
MT.widgets.cropper = (function () {
  var widget = {
    click: function (e, target) {
      var apply = target.closest && target.closest('.image-cropper-apply');
      if (apply) {
        var modal = apply.closest('.modal');
        MT.transport.send({ kind: 'crop_apply', modal: modal && modal.id ? '#' + modal.id : '#image-cropper-modal' });
        return true;
      }
      if (target.closest && target.closest('#image-cropper-modal .cropper-container')) return true; // dragging the crop box is not a step
      if (target.closest && target.closest('#image-cropper-modal [data-bs-dismiss]')) return true;
      return false;
    },
    pointerdown: function (e, target) {
      return !!(target.closest && target.closest('#image-cropper-modal .cropper-container'));
    }
  };
  MT.recording.registerWidget(widget);
  return {};
})();
