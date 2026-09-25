class Lead < ApplicationRecord
  STATUSES = %w[new contacted won lost].freeze
  enum priority: {low: 0, normal: 1, high: 2}, _prefix: true
  validates :name, presence: true
end
