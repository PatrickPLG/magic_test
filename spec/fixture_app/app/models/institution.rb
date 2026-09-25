class Institution < ApplicationRecord
  has_many :employees, class_name: "Institutions::Employee", dependent: :destroy
  has_many :events, class_name: "Events::Event", dependent: :destroy
  has_many :specialities, dependent: :destroy

  # Studiz: an institution signs in through its leader employee's user; an
  # institution without a leader (no `:with_user` trait) cannot sign in.
  def leader
    employees.find_by(employee_type: InstitutionEnum::EmployeeType[:leader])
  end

  def user
    leader&.user
  end
end
