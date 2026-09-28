class Provider < ApplicationRecord
  has_one :user, as: :role, dependent: :destroy
  has_many :discounts, dependent: :destroy
  has_many :invoices, dependent: :destroy

  # Studiz: `create(:provider)` raises RecordInvalid (the CVR number is
  # required), so specs use `create(:provider, :with_cvr)`.
  validates :registration_number, presence: {message: "CVR required"}

  # Studiz: `create(:provider, :with_cvr)` saves, but `valid?` is false
  # afterwards ("Company description en Must have english description") until
  # the :with_english_company_description trait fills it. RSpec accepts it.
  validate :english_company_description, if: :persisted?

  private

  def english_company_description
    errors.add(:description_en, "Must have english description") if description_en.blank?
  end
end
