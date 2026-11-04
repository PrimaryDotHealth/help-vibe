# Back-office hand-offs and tracker links between a conversation and a ticket.
class ThreadLink < ApplicationRecord
  self.primary_key = %i[from_thread_id to_thread_id]
  belongs_to :from_thread, class_name: "SupportThread"
  belongs_to :to_thread, class_name: "SupportThread"
  belongs_to :created_by, class_name: "User", optional: true
end
