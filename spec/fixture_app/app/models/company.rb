class Company < ApplicationRecord
  has_one :user, as: :role, dependent: :destroy
  validates :cvr, presence: true
end
