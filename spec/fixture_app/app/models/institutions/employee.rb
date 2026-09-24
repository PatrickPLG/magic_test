module Institutions
  class Employee < ApplicationRecord
    self.table_name = "institutions_employees"
    belongs_to :institution
    has_one :user, as: :role, dependent: :destroy
  end
end
