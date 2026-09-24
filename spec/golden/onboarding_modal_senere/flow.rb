MagicTest::Testing::GoldenFlow.define("onboarding_modal_senere") do
  description "new student dismisses the onboarding modal with Senere and reads the terms"
  setup <<~RUBY
    let!(:student) { create(:student, automatic_verified: true) }

    before do
      sign_in_as_student(student)
    end
  RUBY
  start "visit(root_path)"

  script do |h|
    page.find("#onboarding-modal.show")
    h.click_on("Senere")
    page.has_no_css?("#onboarding-modal.show")
    h.click_on("Læs Studiz' vilkår")
    accept_suggestion("have_current_path(terms_path)")
    settle
  end
end
