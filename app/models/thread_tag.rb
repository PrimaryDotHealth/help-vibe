class ThreadTag < ApplicationRecord
  self.primary_key = %i[thread_id tag_id]
  belongs_to :thread, class_name: "SupportThread"
  belongs_to :tag
end
