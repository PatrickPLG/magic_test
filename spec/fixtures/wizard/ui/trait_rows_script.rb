# B5 (1.2): a trait toggles when a person clicks its label text or its row,
# exactly that one trait, and the chosen traits show as removable chips.
h = human
def preview_text(page)
  page.evaluate_script("document.getElementById('preview').textContent")
end
wait_until { page.has_css?("#w-description") }
h.click("#w-description").type("provider renames a discount")
h.click("#w-path").select_all.type(ENV.fetch("MAGIC_TEST_UI_TARGET"))
h.click("#next")
wait_until { page.has_css?("#w-role") }
page.find("#w-role").find("option[value='Provider']").select_option
wait_until { page.has_css?("#w-role-trait-with_cvr") }
# the learned default (:with_cvr, from the specs) is pre-ticked: clear it so the clicks below start from nothing
h.click("#w-role-trait-with_cvr") if page.find("#w-role-trait-with_cvr").checked?
wait_until(timeout: 10) { preview_text(page).include?("it 'provider renames a discount' do") } # the pinned preview shows the skeleton (TODO for the start page)

# 1. the label text of the first trait (a nested label used to toggle it twice)
h.click_text(page.find("#w-role-trait-with_cvr").ancestor("label:not(.field)"))
wait_until(timeout: 5) { page.find("#w-role-trait-with_cvr").checked? }
raise "clicking the with_cvr text also toggled: #{page.all("#w-role input[type=checkbox]:checked, .traits input:checked").map { |i| i[:id] }}" unless page.all(".traits input:checked").map { |i| i[:id] } == ["w-role-trait-with_cvr"]
wait_until(timeout: 10) { preview_text(page).include?("create(:provider, :with_cvr)") }

# 2. the whole row, far right of the text (used to hit the group's wrapper label = the first checkbox)
h.click_row(page.find("#w-role-trait-with_user").ancestor("label:not(.field)"))
wait_until(timeout: 5) { page.find("#w-role-trait-with_user").checked? }
raise "the row click toggled the wrong trait: #{page.all(".traits input:checked").map { |i| i[:id] }}" unless page.all(".traits input:checked").map { |i| i[:id] } == %w[w-role-trait-with_cvr w-role-trait-with_user]
wait_until(timeout: 10) { preview_text(page).include?("create(:provider, :with_cvr, :with_user)") }
# 3. a chip per chosen trait, removable
wait_until(timeout: 5) { page.has_css?(".chip[data-let='provider'][data-trait='with_cvr']") }
h.click(".chip[data-let='provider'][data-trait='with_cvr'] .chip-remove")
wait_until(timeout: 5) { !page.find("#w-role-trait-with_cvr").checked? }
wait_until(timeout: 10) { preview_text(page).include?("create(:provider, :with_user)") && !preview_text(page).include?(":with_cvr") }
raise "the chip did not go away" if page.has_css?(".chip[data-trait='with_cvr']")

puts "B5 OK: label text and row toggle exactly one trait; chips add and remove"
session.enqueue("cancel", {})
