class Provider < ApplicationRecord
  has_one :user, as: :role, dependent: :destroy
  has_many :discounts, dependent: :destroy
  has_many :invoices, dependent: :destroy

  # Studiz: `create(:provider)` raises RecordInvalid (the CVR number is
  # required), so specs use `create(:provider, :with_cvr)`.
  validates :registration_number, presence: {message: "CVR required"}
end
