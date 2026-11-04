class ReviewAssignment < ApplicationRecord
  belongs_to :review
  belongs_to :user, optional: true
  belongs_to :group, optional: true
  belongs_to :decided_by, class_name: "User", optional: true

  def label = user&.name || "#{group.name} (any member)"
end
