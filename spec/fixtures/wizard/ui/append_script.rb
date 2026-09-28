# Appends to an existing Studiz-style file: "Existing file", its path, the
# block tree appears; the provider and discount lets are reused, a bare `it` is appended.
h = human
target = ENV.fetch("MAGIC_TEST_UI_TARGET")
# Step 1
wait_until { page.has_css?("#w-description") }
h.click("#w-description").type("provider lists the discounts again")
h.click("#w-target-existing")
wait_until { page.has_css?("#w-path") }
h.click("#w-path").select_all.type(target)
wait_until(timeout: 15) { page.has_css?("#w-block") }
h.click("#next")
# Step 2
wait_until { page.has_css?("#w-role") }
page.find("#w-role").find("option[value='Provider']").select_option
wait_until { page.has_css?("#w-role-trait-with_cvr") }
h.click("#w-role-trait-with_cvr") unless page.find("#w-role-trait-with_cvr").checked?
h.click("#w-factory-filter").type("discount")
page.find("#w-factory").find("option[value='discount']").select_option
h.click("#w-add-model")
wait_until { page.has_css?("#w-model-1-trait-active") }
h.click("#w-model-1-trait-active") unless page.find("#w-model-1-trait-active").checked?
h.click("#next")
# Step 3
wait_until { page.has_css?("#w-route-filter") }
h.click("#w-route-filter").type("provider_admin_discounts")
page.find("#w-route").find("option[value='provider_admin_discounts']").select_option
wait_until { page.has_css?("#w-param-provider_id") }
h.click("#next")
# Step 4
wait_until { page.has_css?("#w-review-path") }
wait_until { page.evaluate_script("document.getElementById('preflight').disabled") == false }
wait_until { page.evaluate_script("document.getElementById('preview').textContent").include?("it 'provider lists the discounts again' do") }
h.click("#preflight")
wait_until(timeout: 90) { state[:status] == "preflighted" }
wait_until { page.has_css?("#preflight-ok") }
wait_until { page.evaluate_script("document.getElementById('start').disabled") == false }
h.click("#start")
wait_until { state[:status] == "recording" }
