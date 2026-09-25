module Institutions
  class Employee < ApplicationRecord
    self.table_name = "institutions_employees"
    belongs_to :institution
    has_one :user, as: :role, dependent: :destroy
    enum employee_type: InstitutionEnum::EmployeeType, _prefix: :type

    def leader?
      employee_type == InstitutionEnum::EmployeeType[:leader]
    end
  end
end
