# A polymorphic child (any record can be annotated) with an optional author.
class Note < ApplicationRecord
  belongs_to :notable, polymorphic: true
  belongs_to :author, class_name: "User", optional: true
  validates :body, presence: true
end
