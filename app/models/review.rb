# A request for review of a draft version (S14). Reviewers are people or
# groups (any member can decide for a group). The rule (any/all) is copied
# from settings when the review is requested.
class Review < ApplicationRecord
  belongs_to :version, class_name: "ArticleVersion"
  belongs_to :requested_by, class_name: "User", optional: true
  has_many :assignments, class_name: "ReviewAssignment", dependent: :delete_all

  scope :pending, -> { where(status: "pending") }

  # Pending reviews this user still has to decide (directly or via a group).
  def self.awaiting(user)
    pending.joins(:assignments).where(review_assignments: { decision: "pending" })
           .where("review_assignments.user_id = :id or review_assignments.group_id in (:groups)", id: user.id, groups: user.group_ids.presence || [ 0 ])
           .distinct
  end

  def self.request!(version:, by:, reviewer_keys:, note: "")
    pairs = Array(reviewer_keys).compact_blank.map { _1.split(":") }.select { %w[user group].include?(_1.first) }
    raise ArgumentError, "Pick at least one reviewer" if pairs.empty?
    transaction do
      version.reviews.pending.update_all(status: "cancelled", decided_at: Time.current)
      review = create!(version: version, requested_by: by, note: note.to_s, rule: Setting["review.rule"])
      pairs.each { |kind, id| review.assignments.create!("#{kind}_id" => id.to_i) }
      review
    end
  end

  # Assignments this user may decide: their own, or a group they're in.
  def assignments_for(user)
    assignments.select { _1.user_id == user.id || (_1.group_id && user.group_ids.include?(_1.group_id)) }
  end

  def decide!(user:, decision:, message: "")
    mine = assignments_for(user).select { _1.decision == "pending" }
    raise ActiveRecord::RecordNotFound, "Not a reviewer" if mine.empty?
    transaction do
      mine.each { _1.update!(decision: decision, message: message.to_s, decided_by: user, decided_at: Time.current) }
      settle!
    end
  end

  def settle!
    decisions = assignments.reload.map(&:decision)
    new_status =
      if decisions.include?("changes_requested") then "changes_requested"
      elsif rule == "any" && decisions.include?("approved") then "approved"
      elsif decisions.all?("approved") then "approved"
      end
    update!(status: new_status, decided_at: Time.current) if new_status
  end

  def reviewer_users
    (assignments.filter_map(&:user) + assignments.filter_map(&:group).flat_map(&:users)).uniq
  end
end
