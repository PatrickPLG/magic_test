# Studiz has factories that leave a NOT NULL parent to the caller:
# `create(:payment)` raises unless an invoice is passed.
class Payment < ApplicationRecord
  belongs_to :invoice
end
