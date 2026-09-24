MagicTest::Testing::GoldenFlow.define("student_org_ajax_modal_form") do
  description "student organisation adds a member through the ajax modal form"
  setup <<~RUBY
    let!(:organisation) { create(:student_organisation) }

    before do
      sign_in_as_student_organisation(organisation)
    end
  RUBY
  start "visit(student_organisation_student_organisation_memberships_path)"

  script do |h|
    h.click_on("Tilføj medlem")
    page.find("#ajax-modal.show #membership-form")
    h.click("#student_organisation_membership_name").type("Ida Nielsen")
    h.click("#student_organisation_membership_email").type("ida@studiz.dk")
    h.native_select("Medlemstype", "Bestyrelse")
    h.click_on("Tilføj")
    wait_for_suggestion("Medlem tilføjet")
    accept_suggestion("Medlem tilføjet")
    accept_suggestion("have_no_css('#ajax-modal.show')")
    accept_suggestion("StudentOrganisationMembership.count")
    settle
  end
end
