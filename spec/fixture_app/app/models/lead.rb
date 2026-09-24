class Lead < ApplicationRecord
  STATUSES = %w[new contacted won lost].freeze
  validates :name, presence: true
end
