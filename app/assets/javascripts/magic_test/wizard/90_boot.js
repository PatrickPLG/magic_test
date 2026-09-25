W.boot = function () {
  W.preview.bind();
  W.api.get('wizard/catalogue').then(function (cat) {
    if (cat.error) { W.preview.notice(cat.error, true); return; }
    W.state.catalogue = cat;
    W.state.plan.start.locale = cat.defaults.locale;
    W.state.plan.target.path = cat.target || cat.suggested_path;
    W.form.render();
    W.preview.refresh();
  }).catch(function (e) { W.preview.notice('could not load the catalogue: ' + e, true); });
};
