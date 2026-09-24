/* Studiz application JavaScript, reduced to the behaviours the recorder must cope with. */
(function () {
  "use strict";

  // --- Chosen (app/assets/javascripts/chosen.js, verbatim options) ---------
  window.initialize_chosen = function () {
    $(".chosen-select").chosen({
      width: "200px",
      no_results_text: I18n.t("search.no_results_found"),
      search_contains: true,
      disable_search_threshold: 4,
      max_shown_results: 500
    });
  };
  window.initialize_chosen_no_search = function () {
    $(".chosen-select-no-search").chosen({ width: "200px", disable_search: true });
  };

  // --- flatpickr (flatpicker.js) --------------------------------------------
  window.initialize_flatpickr = function () {
    $(".js-datetimepicker-field").flatpickr({
      dateFormat: "d/m-Y H:i",
      enableTime: true,
      allowInput: true,
      time_24hr: true,
      weekNumbers: true,
      wrap: true
    });
    $(".js-datepicker-birthday-field").flatpickr({
      dateFormat: "d/m-Y",
      allowInput: true,
      maxDate: new Date().fp_incr(-365 * 10),
      onReady: function (sel, str, instance) {
        // Studiz replaces the year input with a custom <select> of years.
        var years = [];
        var thisYear = new Date().getFullYear();
        for (var y = thisYear - 10; y >= thisYear - 80; y--) years.push(y);
        var select = document.createElement("select");
        select.className = "flatpickr-year-select";
        years.forEach(function (y) {
          var o = document.createElement("option");
          o.value = y;
          o.textContent = y;
          select.appendChild(o);
        });
        var current = instance.currentYearElement;
        select.value = current.value;
        select.addEventListener("change", function () { instance.changeYear(parseInt(select.value, 10)); });
        current.parentNode.replaceChild(select, current);
        instance.currentYearElement = select;
      },
      onOpen: function (sel, dateStr, instance) {
        if (dateStr === "") instance.jumpToDate(new Date().fp_incr(-365 * 20));
      }
    });
  };

  // --- Flash + toast ---------------------------------------------------------
  window.remove_flash = function () {
    var ms = window.innerWidth < 768 ? 4000 : 7000;
    setTimeout(function () { $(".alert").remove(); }, ms);
  };
  window.showToast = function (message) {
    var el = document.getElementById("liveToast");
    if (!el) return;
    el.querySelector(".toast-body").textContent = message;
    bootstrap.Toast.getOrCreateInstance(el, { delay: 4000 }).show();
  };

  // --- Bootstrap modals ------------------------------------------------------
  var spinner = '<div class="modal-header"><button class="btn-close" aria-label="Close" data-bs-dismiss="modal" type="button"></button></div>' +
    '<div class="modal-body"><div class="d-flex justify-content-center"><div class="d-flex spinner-border" role="status"></div>' +
    '<div class="visually-hidden"><div id="load">Loading...</div></div></div></div>';
  function initModals() {
    $("#ajax-modal, #full-view-modal").on("hidden.bs.modal", function () {
      $(this).find(".modal-content").html(spinner);
    });
    $("#ajax-modal, #full-view-modal").on("shown.bs.modal", function () {
      window.initialize_chosen();
    });
    $("[data-auto-open='true']").each(function () {
      bootstrap.Modal.getOrCreateInstance(this).show();
    });
    $(".js-cookie-accept, .js-cookie-necessary").on("click", function () {
      document.cookie = "cookie_settings=" + ($(this).hasClass("js-cookie-accept") ? "all" : "necessary") + "; path=/";
    });
  }

  // --- Cover image + Cropper (cover_image_upload.js) ------------------------
  function initCoverImageUpload() {
    $(document).on("change", ".cover-image-upload", function () {
      var input = this;
      var file = input.files && input.files[0];
      if (!file) return;
      var modalEl = document.querySelector(input.getAttribute("data-cropper-target") || "#image-cropper-modal");
      var img = modalEl.querySelector("img");
      var reader = new FileReader();
      reader.onload = function (e) {
        img.src = e.target.result;
        var modal = bootstrap.Modal.getOrCreateInstance(modalEl);
        $(modalEl).one("shown.bs.modal", function () {
          if (img.cropper) img.cropper.destroy();
          window.__cropper = new Cropper(img, { aspectRatio: 2, viewMode: 1, autoCropArea: 1 });
        });
        modal.show();
        $(modalEl).find(".image-cropper-apply").off("click").on("click", function () {
          try {
            var canvas = window.__cropper.getCroppedCanvas({ width: 200, height: 100 });
            var dataUrl = canvas ? canvas.toDataURL("image/png") : "";
            var blob = dataUrl ? dataURLToBlob(dataUrl) : file;
            var dt = new DataTransfer();
            dt.items.add(new File([blob], file.name, { type: file.type || "image/png" }));
            input.files = dt.files;
          } catch (err) { /* keep original file */ }
          input.setAttribute("data-cropped", "true");
          modal.hide();
        });
      };
      reader.readAsDataURL(file);
    });
  }
  function dataURLToBlob(dataUrl) {
    var parts = dataUrl.split(","), mime = parts[0].match(/:(.*?);/)[1], bin = atob(parts[1]);
    var arr = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
    return new Blob([arr], { type: mime });
  }

  // --- Nested fields (NEW_RECORD -> Date.getTime()) -------------------------
  function initNestedFields() {
    $(document).on("click", ".js-add-ticket-type", function (e) {
      e.preventDefault();
      var template = $(this).data("association-insertion-template");
      var html = template.replace(/NEW_RECORD/g, new Date().getTime());
      $("#ticket-types").append(html);
    });
    $(document).on("click", ".js-remove-ticket-type", function (e) {
      e.preventDefault();
      var wrapper = $(this).closest(".ticket-type-fields");
      wrapper.find("input[name*='_destroy']").val("1");
      wrapper.hide();
    });
  }

  // --- Live support widget: background XHR the recorder must ignore ----------
  function initLiveSupport() {
    var widget = document.getElementById("live-support-widget");
    if (!widget) return;
    var url = widget.getAttribute("data-ping-url");
    setInterval(function () {
      $.ajax({ url: url, method: "GET", dataType: "json" });
    }, 1500);
    $(".js-live-support-toggle").on("click", function () {
      $(".live-support-panel").toggleClass("d-none");
      $.ajax({ url: url, method: "POST", dataType: "json" });
    });
  }

  $(function () {
    window.initialize_chosen();
    window.initialize_chosen_no_search();
    window.initialize_flatpickr();
    window.remove_flash();
    initModals();
    initCoverImageUpload();
    initNestedFields();
    initLiveSupport();
    // Studiz: re-run chosen after AJAX renders.
    $(document).on("ajax:complete", function () { window.initialize_chosen(); });
  });
})();
