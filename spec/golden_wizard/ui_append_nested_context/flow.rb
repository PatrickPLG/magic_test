# 1.2 (B4 through the UI): append into a nested context of a Studiz-style file
# with repeated names, picked from the block tree by its line; the lets of
# 'edit page' and the top-level provider are reused, a bare `it` is appended.
MagicTest::Testing::WizardFlow.define("ui_append_nested_context") do
  existing "nested_duplicates_spec.rb.txt"
  target_name "nested_duplicates_spec.rb"

  ui do
    describe_test("provider renames the discount on the edit page")
    existing_file(ENV.fetch("MAGIC_TEST_UI_TARGET"))
    pick_block("context 'Visuals' (line 34)")
    next_step
    pick_role("Provider")
    set_trait("w-role", "with_cvr")
    add_record("discount")
    set_trait("w-model-1", "active")
    set_attribute(1, "name_da", "Kaffe 20%")
    next_step
    pick_route("edit_provider_admin_discount", "provider_id" => "provider", "id" => "discount")
    next_step
    raise "preflight failed: #{state[:preflight].inspect}" unless run_preflight[:ok]
    start_recording
  end

  script do |h|
    h.click("#discount_name_da").select_all.type("Kaffe 25%")
    h.click_on("Gem")
    wait_for_suggestion("Rabatten er gemt")
    accept_suggestion("Rabatten er gemt")
    accept_suggestion("discount.reload.name_da")
    settle
  end
end
