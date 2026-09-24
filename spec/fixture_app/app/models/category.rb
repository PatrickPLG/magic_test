class Category < ApplicationRecord
  has_and_belongs_to_many :discounts
  has_many :events, class_name: "Events::Event"
end
