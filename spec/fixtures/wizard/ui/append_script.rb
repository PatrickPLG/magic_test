# Appends to an existing Studiz-style file: typing its path lists the blocks,
# the provider and discount lets are reused, a bare `it` is appended.
h = human
target = ENV.fetch("MAGIC_TEST_UI_TARGET")
wait_until { page.has_css?("#w-description") }
h.click("#w-description").type("provider lists the discounts again")
h.click("#w-path").select_all.type(target)
wait_until(timeout: 15) { page.has_css?("#w-block") }
page.find("#w-role").find("option[value='Provider']").select_option
wait_until { page.has_css?("#w-role-trait-with_cvr") }
h.click("#w-role-trait-with_cvr")
h.click("#w-factory-filter").type("discount")
page.find("#w-factory").find("option[value='discount']").select_option
h.click("#w-add-model")
wait_until { page.has_css?("#w-model-1-trait-active") }
h.click("#w-model-1-trait-active")
h.click("#w-route-filter").type("provider_admin_discounts")
page.find("#w-route").find("option[value='provider_admin_discounts']").select_option
wait_until { page.has_css?("#w-param-provider_id") }
wait_until { page.evaluate_script("document.getElementById('preflight').disabled") == false }
wait_until { page.evaluate_script("document.getElementById('preview').textContent").include?("it 'provider lists the discounts again' do") }
h.click("#preflight")
wait_until(timeout: 90) { state[:status] == "preflighted" } # poll the server, not the browser the preflight is driving
wait_until { page.has_css?("#preflight-ok") }
wait_until { page.evaluate_script("document.getElementById('start').disabled") == false }
h.click("#start")
wait_until { state[:status] == "recording" }
