class Institution < ApplicationRecord
  has_many :employees, class_name: "Institutions::Employee", dependent: :destroy
  has_many :events, class_name: "Events::Event", dependent: :destroy
  has_many :specialities, dependent: :destroy

  def leader
    employees.find_by(leader: true) || employees.first
  end

  def user
    leader&.user
  end
end
