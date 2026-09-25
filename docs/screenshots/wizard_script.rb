# Drives the browser wizard for the README screenshots (rake docs:screenshots).
h = human
dir = ENV.fetch("MAGIC_TEST_SCREENSHOT_DIR")
target = ENV.fetch("MAGIC_TEST_UI_TARGET")
shot = ->(name) { sleep 0.6; page.save_screenshot(File.join(dir, name)) }
wait_until { page.has_css?("#w-description") }
h.click("#w-description").type("provider renames a discount")
page.find("#w-role").find("option[value='Provider']").select_option
wait_until { page.has_css?("#w-role-trait-with_cvr") }
h.click("#w-role-trait-with_cvr")
h.click("#w-path").select_all.type(target)
h.click("#w-factory-filter").type("discount")
page.find("#w-factory").find("option[value='discount']").select_option
h.click("#w-add-model")
wait_until { page.has_css?("#w-model-1-trait-active") }
h.click("#w-model-1-trait-active")
h.click("#w-route-filter").type("provider_admin_discounts")
page.find("#w-route").find("option[value='provider_admin_discounts']").select_option
wait_until { page.has_css?("#w-param-provider_id") }
wait_until { page.evaluate_script("document.getElementById('preflight').disabled") == false }
page.execute_script("document.getElementById('form').scrollTop = 0")
shot.call("wizard-form.png")
h.click("#preflight")
wait_until(timeout: 90) { state[:status] == "preflighted" } # poll the server, not the browser the preflight is driving
wait_until { page.has_css?("#preflight-ok") }
page.execute_script("document.querySelector('.col:last-child').scrollTop = 0")
shot.call("wizard-preflight.png")
wait_until { page.evaluate_script("document.getElementById('start').disabled") == false }
h.click("#start")
wait_until { state[:status] == "recording" }
