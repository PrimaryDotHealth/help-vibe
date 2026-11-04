class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :thread, class_name: "SupportThread", optional: true
  scope :unread, -> { where(read_at: nil) }
end
