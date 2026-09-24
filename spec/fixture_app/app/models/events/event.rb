module Events
  class Event < ApplicationRecord
    self.table_name = "events_events"
    belongs_to :institution
    belongs_to :category, optional: true
    has_many :ticket_types, class_name: "Events::TicketType", foreign_key: :event_id, dependent: :destroy, inverse_of: :event
    accepts_nested_attributes_for :ticket_types, allow_destroy: true, reject_if: :all_blank
    validates :name, presence: true
  end
end
