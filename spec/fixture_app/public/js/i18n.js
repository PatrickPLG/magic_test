// Minimal stand-in for the i18n-js runtime Studiz uses in chosen.js.
window.I18n = {
  translations: {
    da: { "search.no_results_found": "Ingen resultater fundet" },
    en: { "search.no_results_found": "No results found" }
  },
  locale: document.documentElement.lang || "da",
  t: function (key) {
    var table = this.translations[this.locale] || this.translations.da;
    return table[key] || key;
  }
};
