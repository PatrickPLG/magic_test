// Flat config for the recorder sources: plain ES2017 browser scripts that
// share the bundle-private `MT` namespace (see lib/magic_test/recorder_bundle.rb).
module.exports = [
  {
    files: ["app/assets/javascripts/magic_test/src/**/*.js"],
    languageOptions: {
      ecmaVersion: 2017,
      sourceType: "script",
      globals: {
        window: "readonly", document: "readonly", navigator: "readonly", performance: "readonly",
        setTimeout: "readonly", clearTimeout: "readonly", setInterval: "readonly", clearInterval: "readonly",
        fetch: "readonly", XMLHttpRequest: "readonly", URL: "readonly", Event: "readonly", CustomEvent: "readonly",
        MouseEvent: "readonly", KeyboardEvent: "readonly", XPathResult: "readonly", MutationObserver: "readonly",
        Node: "readonly", console: "readonly", CSS: "readonly", Promise: "readonly", Map: "readonly", Set: "readonly",
        WeakMap: "readonly", Array: "readonly", Object: "readonly", JSON: "readonly", Date: "readonly", Math: "readonly",
        String: "readonly", Number: "readonly", Error: "readonly", parseInt: "readonly", parseFloat: "readonly",
        Uint8Array: "readonly", PointerEvent: "readonly", MT: "writable"
      }
    },
    rules: {
      "no-undef": "error",
      "no-unused-vars": ["error", { args: "none", caughtErrors: "none" }],
      "no-implicit-globals": "error",
      "no-var": "off",
      "eqeqeq": ["error", "always"],
      "no-console": ["error", { allow: ["warn"] }]
    }
  },
  {
    // The wizard page (lib/magic_test/wizard_bundle.rb): bundle-private `W` namespace, plain DOM.
    files: ["app/assets/javascripts/magic_test/wizard/**/*.js"],
    languageOptions: {
      ecmaVersion: 2017,
      sourceType: "script",
      globals: {
        window: "readonly", document: "readonly", setTimeout: "readonly", clearTimeout: "readonly", fetch: "readonly",
        confirm: "readonly", prompt: "readonly", JSON: "readonly", Object: "readonly", Array: "readonly", Math: "readonly",
        String: "readonly", parseInt: "readonly", W: "writable"
      }
    },
    rules: {
      "no-undef": "error",
      "no-unused-vars": ["error", { args: "none", caughtErrors: "none" }],
      "no-implicit-globals": "error",
      "eqeqeq": ["error", "always"],
      "no-console": ["error", { allow: ["warn"] }]
    }
  },
  {
    files: ["spec/js/**/*.js"],
    languageOptions: {
      ecmaVersion: 2017,
      sourceType: "script",
      globals: { window: "readonly", document: "readonly", MouseEvent: "readonly", Array: "readonly", Object: "readonly", JSON: "readonly", String: "readonly", Error: "readonly", setTimeout: "readonly" }
    },
    rules: { "no-undef": "error", "no-unused-vars": ["error", { args: "none", caughtErrors: "none" }] }
  }
];
