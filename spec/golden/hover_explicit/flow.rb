MagicTest::Testing::GoldenFlow.define("hover_explicit") do
  description "student records an explicit hover on the help menu, then clicks a revealed link"
  setup ""
  start "visit(root_path)"

  script do |h|
    # The help menu opens on mouseenter only (no click). The recorder ignores
    # plain mouse moves; Alt+Shift+H records a hover on the element under the pointer.
    h.hover("#helpMenu > a")
    h.press("H", :alt, :shift)
    wait_for_steps(1)
    page.find("#helpMenu .dropdown-menu.show", wait: 5)
    h.click_on("Vilkår")
    settle
  end
end
