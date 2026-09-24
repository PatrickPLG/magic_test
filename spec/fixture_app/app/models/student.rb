class Student < ApplicationRecord
  has_one :user, as: :role, dependent: :destroy

  def full_name
    [first_name, last_name].compact.join(" ")
  end
end
