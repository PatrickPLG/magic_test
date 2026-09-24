module ApplicationHelper
  # Verbatim shape of Studiz's FlashHelper#flash_messages (Appendix C.4).
  def flash_messages
    flash.map do |type, msg|
      next if msg.blank?
      type = {"notice" => "info", "alert" => "danger", "error" => "danger"}.fetch(type.to_s, type.to_s)
      content_tag(:div, msg.html_safe + content_tag(:button, nil, class: "btn-close", aria: {label: "Close"}, data: {"bs-dismiss": "alert"}),
        class: ["alert alert-dismissible fade show alert-#{type} mt-3 fw-bold",
          params["controller"].to_s.include?("institutions") ? "col-sm-11" : "position-fixed w-100"])
    end.compact.join.html_safe
  end

  # ActionText-style rich text area: hidden input with a render-order id
  # (`trix_input_N`), `<trix-editor id=... input=trix_input_N>`.
  def rich_text_area_tag(name, value, id:)
    ApplicationHelper.trix_counter += 1
    input_id = "trix_input_#{ApplicationHelper.trix_counter}"
    hidden_field_tag(name, value, id: input_id) +
      content_tag("trix-editor", nil, id: id, input: input_id, class: "trix-content form-control")
  end

  class << self
    attr_accessor :trix_counter
  end
  self.trix_counter = 0

  def discount_status_options
    Discount::STATUSES.map { |s| [t("discounts.statuses.#{s}"), s] }
  end

  def membership_type_options
    %w[member board].map { |s| [t("memberships.types.#{s}"), s] }
  end
end
