class Provider < ApplicationRecord
  has_one :user, as: :role, dependent: :destroy
  has_many :discounts, dependent: :destroy
  has_many :invoices, dependent: :destroy
end
