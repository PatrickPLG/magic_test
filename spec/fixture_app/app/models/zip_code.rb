class ZipCode < ApplicationRecord
  has_many :providers, dependent: :restrict_with_error
end
