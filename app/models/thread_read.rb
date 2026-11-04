class ThreadRead < ApplicationRecord
  self.primary_key = %i[thread_id user_id]
  belongs_to :thread, class_name: "SupportThread"
  belongs_to :user
end
