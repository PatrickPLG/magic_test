class Invoice < ApplicationRecord
  has_many :payments, dependent: :destroy
  belongs_to :provider
end
