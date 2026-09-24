// Browser-side twin of MagicTest::DynamicValues: ids/names/classes/hrefs that
// depend on a database row, a counter, a timestamp or a placeholder.
MT.dynamic = (function () {
  var BOOTSTRAP_UTILITY_CLASSES = {};
  ('active show fade collapse collapsing collapsed disabled visually-hidden visually-hidden-focusable stretched-link text-truncate vr clearfix ' +
   'sticky-top sticky-bottom fixed-top fixed-bottom container container-fluid row col d-inline d-inline-block d-block d-grid d-table d-table-row d-table-cell d-flex d-inline-flex d-none ' +
   'align-baseline align-top align-middle align-bottom align-text-bottom align-text-top float-start float-end float-none ' +
   'overflow-auto overflow-hidden overflow-visible overflow-scroll shadow shadow-sm shadow-lg shadow-none rounded rounded-0 rounded-1 rounded-2 rounded-3 rounded-4 rounded-5 rounded-circle rounded-pill ' +
   'border border-0 border-top border-end border-bottom border-start fw-bold fw-bolder fw-semibold fw-medium fw-normal fw-light fw-lighter fst-italic fst-normal ' +
   'text-start text-end text-center text-wrap text-nowrap text-break text-lowercase text-uppercase text-capitalize text-muted text-body text-body-secondary text-body-tertiary text-black text-white text-reset ' +
   'text-decoration-none text-decoration-underline text-decoration-line-through lh-1 lh-sm lh-base lh-lg user-select-all user-select-auto user-select-none pe-none pe-auto ' +
   'position-static position-relative position-absolute position-fixed position-sticky w-25 w-50 w-75 w-100 w-auto h-25 h-50 h-75 h-100 h-auto mw-100 mh-100 vw-100 vh-100 min-vw-100 min-vh-100 ' +
   'justify-content-start justify-content-end justify-content-center justify-content-between justify-content-around justify-content-evenly ' +
   'align-items-start align-items-end align-items-center align-items-baseline align-items-stretch align-self-start align-self-end align-self-center align-self-baseline align-self-stretch ' +
   'flex-row flex-column flex-row-reverse flex-column-reverse flex-wrap flex-nowrap flex-fill flex-grow-0 flex-grow-1 flex-shrink-0 flex-shrink-1 order-first order-last invisible visible ' +
   'opacity-0 opacity-25 opacity-50 opacity-75 opacity-100 bg-primary bg-secondary bg-success bg-danger bg-warning bg-info bg-light bg-dark bg-white bg-transparent bg-body ' +
   'text-primary text-secondary text-success text-danger text-warning text-info text-light text-dark border-primary border-secondary border-success border-danger border-warning border-info border-light border-dark ' +
   'link-primary link-secondary link-success link-danger link-warning link-info link-light link-dark me-auto ms-auto mx-auto').split(' ').forEach(function (c) { BOOTSTRAP_UTILITY_CLASSES[c] = true; });

  var BOOTSTRAP_UTILITY_PATTERN = new RegExp('^(?:' + [
    '(?:m|p)(?:t|b|s|e|x|y)?-(?:sm-|md-|lg-|xl-|xxl-)?(?:auto|n?[0-5])',
    'gap-(?:sm-|md-|lg-|xl-|xxl-)?[0-5]', '(?:row|column)-gap-[0-5]',
    'col-(?:sm-|md-|lg-|xl-|xxl-)?(?:auto|[0-9]{1,2})', 'col-(?:sm|md|lg|xl|xxl)', 'row-cols-(?:sm-|md-|lg-|xl-|xxl-)?(?:auto|[1-6])',
    'offset-(?:sm-|md-|lg-|xl-|xxl-)?[0-9]{1,2}', 'g[xy]?-(?:sm-|md-|lg-|xl-|xxl-)?[0-5]', 'order-(?:sm-|md-|lg-|xl-|xxl-)?(?:first|last|[0-5])',
    'fs-[1-6]', 'z-(?:n1|[0-3])', 'top-(?:0|50|100)', 'bottom-(?:0|50|100)', 'start-(?:0|50|100)', 'end-(?:0|50|100)', 'translate-middle(?:-x|-y)?',
    'd-(?:sm|md|lg|xl|xxl|print)-(?:none|inline|inline-block|block|grid|table|table-row|table-cell|flex|inline-flex)',
    'flex-(?:sm|md|lg|xl|xxl)-(?:row|column|row-reverse|column-reverse|wrap|nowrap|fill|grow-[01]|shrink-[01])',
    'justify-content-(?:sm|md|lg|xl|xxl)-(?:start|end|center|between|around|evenly)', 'align-(?:items|self)-(?:sm|md|lg|xl|xxl)-(?:start|end|center|baseline|stretch)',
    'text-(?:sm|md|lg|xl|xxl)-(?:start|end|center)', 'float-(?:sm|md|lg|xl|xxl)-(?:start|end|none)',
    '(?:bg|text|border)-(?:primary|secondary|success|danger|warning|info|light|dark|black|white)-subtle',
    'text-opacity-(?:25|50|75|100)', 'bg-opacity-(?:10|25|50|75|100)', 'border-opacity-(?:10|25|50|75|100)', 'border-[1-5]',
    'rounded-(?:top|end|bottom|start)(?:-[0-5])?', 'font-monospace', 'lead', 'display-[1-6]', 'small', 'mark', 'initialism',
    'btn-(?:sm|lg)', 'form-control-(?:sm|lg)', 'input-group-(?:sm|lg)', 'table-(?:sm|striped|hover|bordered|borderless|responsive)'
  ].join('|') + ')$');

  var EPOCH_MS = /\d{10,}/;
  var UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  var HEX_TOKEN = /^[0-9a-f]{16,}$/i;
  var NESTED_INDEX = /_attributes_\d+_|\[\d+\]|_attributes\]\[\d+\]/;
  var TRIX_INPUT = /^trix[-_]input[-_]\d+$/;
  var PLACEHOLDERS = /NEW_RECORD|NEW_VARIANT|new_record|new_variant/;
  var CHOSEN_CONTAINER = /_chosen$/;
  var CLIENT_GENERATED_ID = /^(?:ui-id-|select2-|chosen-|tooltip\d|popover\d|flatpickr|cropper|toast|dropdown-menu)/;

  function knownIds() {
    return (MT.config && MT.config.known_ids) || [];
  }

  function embedsKnownId(value, ids) {
    ids = ids || knownIds();
    if (!ids.length) return false;
    var numbers = String(value).match(/\d+/g) || [];
    return numbers.some(function (n) { return ids.indexOf(n) !== -1; });
  }

  function isDynamic(value, ids) {
    value = String(value || '');
    if (!value) return false;
    if (EPOCH_MS.test(value)) return true;
    if (UUID.test(value) || HEX_TOKEN.test(value)) return true;
    if (NESTED_INDEX.test(value)) return true;
    if (TRIX_INPUT.test(value)) return true;
    if (PLACEHOLDERS.test(value)) return true;
    if (CLIENT_GENERATED_ID.test(value)) return true;
    if (embedsKnownId(value, ids)) return true;
    return false;
  }

  function isBootstrapUtility(klass) {
    return !!BOOTSTRAP_UTILITY_CLASSES[klass] || BOOTSTRAP_UTILITY_PATTERN.test(klass);
  }

  // Transient state classes (validation, focus, open widgets) are never locators.
  var STATE_CLASSES = /^(?:form-group-valid|form-group-invalid|is-valid|is-invalid|was-validated|field_with_errors|has-error|has-success|hover|focus|focused|open|opened|closed|selected|highlighted|loading|loaded|dragging|dirty|touched|chosen-container-active|chosen-with-drop|chosen-container-single-nosearch|result-selected|active-result|highlighted|flatpickr-input|tooltip-active)$/;

  function semanticClasses(node) {
    if (!node || !node.classList) return [];
    return Array.from(node.classList).filter(function (c) {
      return c && !isBootstrapUtility(c) && !isDynamic(c) && !STATE_CLASSES.test(c) && !/^js-hover/.test(c);
    });
  }

  function stableId(node) {
    var id = node && node.id;
    if (!id) return null;
    if (isDynamic(id) || CHOSEN_CONTAINER.test(id)) return null;
    return id;
  }

  function stableName(node) {
    var name = node && node.name;
    if (!name) return null;
    if (isDynamic(name)) return null;
    return name;
  }

  function hrefPattern(href) {
    if (!href) return null;
    return String(href).replace(/[?#].*$/, '').replace(/\/\d+(?=\/|$)/g, '/*');
  }

  return { isDynamic: isDynamic, isBootstrapUtility: isBootstrapUtility, semanticClasses: semanticClasses, stableId: stableId, stableName: stableName, hrefPattern: hrefPattern, embedsKnownId: embedsKnownId };
})();
