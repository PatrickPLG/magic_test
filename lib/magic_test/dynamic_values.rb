module MagicTest
  # Detects ids, names, classes and hrefs that depend on a database row, a
  # render-order counter, a timestamp or a client-side placeholder. Anything
  # matched here must never end up in a generated locator.
  module DynamicValues
    BOOTSTRAP_UTILITY_CLASSES = %w[
      active show fade collapse collapsing collapsed disabled visually-hidden visually-hidden-focusable
      stretched-link text-truncate vr clearfix ratio ratio-1x1 ratio-4x3 ratio-16x9 ratio-21x9
      sticky-top sticky-bottom fixed-top fixed-bottom container container-fluid row col
      d-inline d-inline-block d-block d-grid d-table d-table-row d-table-cell d-flex d-inline-flex d-none
      align-baseline align-top align-middle align-bottom align-text-bottom align-text-top
      float-start float-end float-none object-fit-contain object-fit-cover object-fit-fill
      overflow-auto overflow-hidden overflow-visible overflow-scroll
      shadow shadow-sm shadow-lg shadow-none rounded rounded-0 rounded-1 rounded-2 rounded-3 rounded-4 rounded-5
      rounded-circle rounded-pill border border-0 border-top border-end border-bottom border-start
      fw-bold fw-bolder fw-semibold fw-medium fw-normal fw-light fw-lighter fst-italic fst-normal
      text-start text-end text-center text-wrap text-nowrap text-break text-lowercase text-uppercase text-capitalize
      text-muted text-body text-body-secondary text-body-tertiary text-black text-white text-reset text-decoration-none
      text-decoration-underline text-decoration-line-through lh-1 lh-sm lh-base lh-lg
      user-select-all user-select-auto user-select-none pe-none pe-auto
      position-static position-relative position-absolute position-fixed position-sticky
      w-25 w-50 w-75 w-100 w-auto h-25 h-50 h-75 h-100 h-auto mw-100 mh-100 vw-100 vh-100 min-vw-100 min-vh-100
      justify-content-start justify-content-end justify-content-center justify-content-between justify-content-around justify-content-evenly
      align-items-start align-items-end align-items-center align-items-baseline align-items-stretch
      align-self-start align-self-end align-self-center align-self-baseline align-self-stretch
      flex-row flex-column flex-row-reverse flex-column-reverse flex-wrap flex-nowrap flex-fill flex-grow-0 flex-grow-1 flex-shrink-0 flex-shrink-1
      order-first order-last invisible visible opacity-0 opacity-25 opacity-50 opacity-75 opacity-100
      bg-primary bg-secondary bg-success bg-danger bg-warning bg-info bg-light bg-dark bg-white bg-transparent bg-body
      text-primary text-secondary text-success text-danger text-warning text-info text-light text-dark
      border-primary border-secondary border-success border-danger border-warning border-info border-light border-dark
      link-primary link-secondary link-success link-danger link-warning link-info link-light link-dark
      me-auto ms-auto mx-auto
    ].to_set.freeze

    # Bootstrap 5.3 responsive/numbered utility families: m-1, px-lg-3, gap-2,
    # fs-4, top-50, start-0, translate-middle, col-md-6, g-3, order-2, z-3...
    BOOTSTRAP_UTILITY_PATTERN = /\A(?:
      (?:m|p)(?:t|b|s|e|x|y)?-(?:sm-|md-|lg-|xl-|xxl-)?(?:auto|n?[0-5])
      |gap-(?:sm-|md-|lg-|xl-|xxl-)?[0-5]|(?:row|column)-gap-[0-5]
      |col-(?:sm-|md-|lg-|xl-|xxl-)?(?:auto|[0-9]{1,2})|col-(?:sm|md|lg|xl|xxl)
      |row-cols-(?:sm-|md-|lg-|xl-|xxl-)?(?:auto|[1-6])
      |offset-(?:sm-|md-|lg-|xl-|xxl-)?[0-9]{1,2}|g[xy]?-(?:sm-|md-|lg-|xl-|xxl-)?[0-5]
      |order-(?:sm-|md-|lg-|xl-|xxl-)?(?:first|last|[0-5])
      |fs-[1-6]|z-(?:n1|[0-3])|top-(?:0|50|100)|bottom-(?:0|50|100)|start-(?:0|50|100)|end-(?:0|50|100)
      |translate-middle(?:-x|-y)?|w-(?:25|50|75|100|auto)|h-(?:25|50|75|100|auto)
      |d-(?:sm|md|lg|xl|xxl|print)-(?:none|inline|inline-block|block|grid|table|table-row|table-cell|flex|inline-flex)
      |flex-(?:sm|md|lg|xl|xxl)-(?:row|column|row-reverse|column-reverse|wrap|nowrap|fill|grow-[01]|shrink-[01])
      |justify-content-(?:sm|md|lg|xl|xxl)-(?:start|end|center|between|around|evenly)
      |align-(?:items|self)-(?:sm|md|lg|xl|xxl)-(?:start|end|center|baseline|stretch)
      |text-(?:sm|md|lg|xl|xxl)-(?:start|end|center)
      |float-(?:sm|md|lg|xl|xxl)-(?:start|end|none)
      |(?:bg|text|border)-(?:primary|secondary|success|danger|warning|info|light|dark|black|white)-subtle
      |text-opacity-(?:25|50|75|100)|bg-opacity-(?:10|25|50|75|100)|border-opacity-(?:10|25|50|75|100)|border-[1-5]
      |rounded-(?:top|end|bottom|start)(?:-[0-5])?|font-monospace|lead|display-[1-6]|small|mark|initialism
      |btn-(?:sm|lg)|form-control-(?:sm|lg)|input-group-(?:sm|lg)|table-(?:sm|striped|hover|bordered|borderless|responsive)
    )\z/x

    EPOCH_MS = /\d{10,}/
    UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    HEX_TOKEN = /\A[0-9a-f]{16,}\z/i
    NESTED_INDEX = /_attributes_\d+_|\[\d+\]|_attributes\]\[\d+\]/
    TRIX_INPUT = /\Atrix[-_]input[-_]\d+\z/
    PLACEHOLDERS = /NEW_RECORD|NEW_VARIANT|new_record|new_variant/
    CHOSEN_CONTAINER = /_chosen\z/
    CLIENT_GENERATED_ID = /\A(?:ui-id-|select2-|chosen-|tooltip\d|popover\d|flatpickr|cropper|toast|dropdown-menu)/

    module_function

    def bootstrap_utility_class?(klass)
      BOOTSTRAP_UTILITY_CLASSES.include?(klass) || BOOTSTRAP_UTILITY_PATTERN.match?(klass)
    end

    STATE_CLASSES = %w[form-group-valid form-group-invalid is-valid is-invalid was-validated field_with_errors has-error has-success
      hover focus focused open opened closed selected highlighted loading loaded dragging dirty touched
      chosen-container-active chosen-with-drop chosen-container-single-nosearch result-selected active-result flatpickr-input tooltip-active].to_set.freeze

    def semantic_classes(classes)
      Array(classes).reject { |c| c.blank? || bootstrap_utility_class?(c) || dynamic?(c, []) || STATE_CLASSES.include?(c) }
    end

    # True when the value embeds a record id (from the ids seen in this
    # session), a nested-attribute index, an epoch-ms number, a Trix counter,
    # a UUID/hex token, a client placeholder or a client-generated widget id.
    def dynamic?(value, known_ids)
      value = value.to_s
      return false if value.empty?
      return true if EPOCH_MS.match?(value)
      return true if UUID.match?(value) || HEX_TOKEN.match?(value)
      return true if NESTED_INDEX.match?(value)
      return true if TRIX_INPUT.match?(value)
      return true if PLACEHOLDERS.match?(value)
      return true if CLIENT_GENERATED_ID.match?(value)
      return true if embeds_known_id?(value, known_ids)
      false
    end

    # `discount-card-42`, `invoice_17`, `cover_image_discount_42_image`,
    # `events_event_ticket_types_attributes_3_name` (the `_3_` is covered above).
    def embeds_known_id?(value, known_ids)
      ids = Array(known_ids).map(&:to_s).to_set
      return false if ids.empty?
      value.scan(/\d+/).any? { |n| ids.include?(n) }
    end

    # Stable if not dynamic; Rails form ids like `events_event_name` are stable.
    def stable_id?(id, known_ids)
      id.present? && !dynamic?(id, known_ids) && !CHOSEN_CONTAINER.match?(id)
    end

    def stable_name?(name, known_ids)
      name.present? && !dynamic?(name, known_ids)
    end

    # Strips numeric ids out of an href so `/udbydere/42/admin/rabatter/7/rediger`
    # becomes `/udbydere/*/admin/rabatter/*/rediger`; used for `href:` filters.
    def href_pattern(href)
      return nil if href.blank?
      href.to_s.sub(/[?#].*\z/, "").gsub(%r{/\d+(?=/|\z)}, "/*")
    end
  end
end
