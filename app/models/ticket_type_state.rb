class TicketTypeState < ApplicationRecord
  self.primary_key = %i[ticket_type_id state_id]
  belongs_to :ticket_type
  belongs_to :state, class_name: "TicketState"
end
