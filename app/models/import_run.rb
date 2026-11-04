class ImportRun < ApplicationRecord
  belongs_to :started_by, class_name: "User", optional: true
  scope :recent, -> { order(started_at: :desc) }
  def running? = status == "running"
end
