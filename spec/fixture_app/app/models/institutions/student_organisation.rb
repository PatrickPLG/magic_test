module Institutions
  class StudentOrganisation < ApplicationRecord
    self.table_name = "institutions_student_organisations"
    has_one :user, as: :role, dependent: :destroy
    has_many :memberships, class_name: "StudentOrganisationMembership", foreign_key: :student_organisation_id, dependent: :destroy
  end
end
