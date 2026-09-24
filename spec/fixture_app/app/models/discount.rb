class Discount < ApplicationRecord
  STATUSES = %w[draft active inactive].freeze
  belongs_to :provider
  has_and_belongs_to_many :categories
  validates :name_da, presence: true
  validates :status, inclusion: {in: STATUSES}
end
