W.boot = function () {
  W.preview.bind();
  W.api.get('wizard/catalogue').then(function (cat) {
    if (cat.error) { W.preview.notice(cat.error, true); return; }
    W.state.catalogue = cat;
    W.state.plan.start.locale = cat.defaults.locale;
    if (cat.template_plan) {
      // `bin/magic new --template <name> "description"`: straight to review & preflight.
      W.steps.loadPlan(cat.template_plan, 'template:cli');
      W.state.plan.description = cat.template_plan.description || W.state.plan.description;
      if (cat.target) { W.state.plan.target = { path: cat.target, block: null }; W.state.pathEdited = true; }
      W.state.step = 4;
      W.state.nextPressed = { 1: true, 2: true, 3: true };
    } else if (cat.target) {
      W.state.plan.target.path = cat.target;
      W.state.pathEdited = true;
    }
    W.steps.render();
    W.preview.refresh();
  }).catch(function (e) { W.preview.notice('could not load the catalogue: ' + e, true); });

  // Keyboard: Enter moves on (not inside a select or a button), Esc closes a hint.
  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Enter' || e.defaultPrevented) return;
    var t = e.target;
    if (t && /^(SELECT|BUTTON|TEXTAREA)$/.test(t.tagName)) return;
    if (t && t.tagName === 'INPUT' && t.type === 'checkbox') return;
    if (W.state.status === 'recording' || W.state.step === 4) return;
    e.preventDefault();
    W.steps.next();
  });
};
