# 1.2 (B3 through the UI): the block was picked from the tree and preflight
# passed, then someone renamed that context in the editor. Start must refuse
# ("block not found") and leave the file exactly as it is on disk.
MagicTest::Testing::WizardFlow.define("ui_b3_refusal") do
  existing "provider_discounts_spec.rb.txt"
  target_name "provider_discounts_spec.rb"
  expect_start_failure(/block not found in .*provider_discounts_spec\.rb: Provider discounts > when the discount is archived/)

  ui do
    describe_test("provider sees the archived discount")
    existing_file(ENV.fetch("MAGIC_TEST_UI_TARGET"))
    pick_block("context 'when the discount is archived' (line 18)")
    next_step
    pick_role("Provider")
    set_trait("w-role", "with_cvr")
    next_step
    pick_route("provider_admin_discounts", "provider_id" => "provider")
    next_step
    raise "preflight failed: #{state[:preflight].inspect}" unless run_preflight[:ok]
    target = ENV.fetch("MAGIC_TEST_UI_TARGET")
    File.write(target, File.read(target).sub("context 'when the discount is archived' do", "context 'when archived' do"))
    snapshot_target_before_start
    ui.click("#start")
    wait_until(timeout: 15) { page.evaluate_script("document.getElementById('notice').textContent").include?("block not found") }
    puts "B3 UI OK: #{page.evaluate_script("document.getElementById('notice').textContent")}"
    session.enqueue("cancel", {})
  end

  script { |_h| settle }
end
