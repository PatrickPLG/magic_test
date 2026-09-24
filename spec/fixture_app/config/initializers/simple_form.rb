# Studiz simple_form configuration (5.1, Bootstrap 5 wrappers, vertical forms).
SimpleForm.setup do |config|
  config.error_notification_class = "alert alert-danger"
  config.button_class = "btn"
  config.boolean_label_class = nil
  config.browser_validations = false
  config.boolean_style = :nested
  config.default_form_class = nil
  config.label_text = lambda { |label, required, explicit_label| "#{required} #{label}" }
  config.generate_additional_classes_for = []

  config.wrappers :vertical_form, class: "mb-3", error_class: "form-group-invalid", valid_class: "form-group-valid" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.use :label, class: "form-label"
    b.use :input, class: "form-control", error_class: "is-invalid", valid_class: "is-valid"
    b.use :full_error, wrap_with: {class: "invalid-feedback"}
    b.use :hint, wrap_with: {class: "form-text"}
  end

  config.wrappers :vertical_select, class: "mb-3", error_class: "form-group-invalid", valid_class: "form-group-valid" do |b|
    b.use :html5
    b.optional :readonly
    b.use :label, class: "form-label"
    b.use :input, class: "form-select", error_class: "is-invalid", valid_class: "is-valid"
    b.use :full_error, wrap_with: {class: "invalid-feedback"}
    b.use :hint, wrap_with: {class: "form-text"}
  end

  config.wrappers :vertical_boolean, class: "mb-3 form-check", error_class: "form-group-invalid", valid_class: "form-group-valid" do |b|
    b.use :html5
    b.optional :readonly
    b.use :input, class: "form-check-input", error_class: "is-invalid", valid_class: "is-valid"
    b.use :label, class: "form-check-label"
    b.use :full_error, wrap_with: {class: "invalid-feedback"}
    b.use :hint, wrap_with: {class: "form-text"}
  end

  config.wrappers :vertical_file, class: "mb-3", error_class: "form-group-invalid", valid_class: "form-group-valid" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :readonly
    b.use :label, class: "form-label"
    b.use :input, class: "form-control", error_class: "is-invalid", valid_class: "is-valid"
    b.use :full_error, wrap_with: {class: "invalid-feedback"}
    b.use :hint, wrap_with: {class: "form-text"}
  end

  config.default_wrapper = :vertical_form
  config.wrapper_mappings = {
    boolean: :vertical_boolean,
    check_boxes: :vertical_form,
    file: :vertical_file,
    radio_buttons: :vertical_form,
    select: :vertical_select
  }
end
