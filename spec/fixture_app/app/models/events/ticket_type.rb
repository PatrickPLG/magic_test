module Events
  class TicketType < ApplicationRecord
    self.table_name = "events_ticket_types"
    belongs_to :event, class_name: "Events::Event", inverse_of: :ticket_types
  end
end
