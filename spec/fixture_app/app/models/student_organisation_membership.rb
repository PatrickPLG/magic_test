class StudentOrganisationMembership < ApplicationRecord
  belongs_to :student_organisation, class_name: "Institutions::StudentOrganisation"
  validates :name, :email, presence: true
end
