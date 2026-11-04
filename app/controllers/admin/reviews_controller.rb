# S14: request a review of a draft, and approve or request changes.
class Admin::ReviewsController < Admin::BaseController
  def create
    version = ArticleVersion.find(params[:version_id])
    review = Review.request!(version: version, by: Current.user, reviewer_keys: params[:reviewer_keys], note: params[:note])
    review.reviewer_users.reject { _1 == Current.user }.each { ReviewMailer.requested(review, _1).deliver_later }
    Activity.record!(version.article, "review_requested", by: Current.user)
    redirect_to edit_admin_article_path(version.article), notice: "Review requested"
  rescue ArgumentError => e
    redirect_to edit_admin_article_path(version.article), alert: e.message
  end

  def decide
    review = Review.find(params[:id])
    decision = params[:decision] == "approved" ? "approved" : "changes_requested"
    review.decide!(user: Current.user, decision: decision, message: params[:message])
    ReviewMailer.decided(review, Current.user, decision, params[:message].to_s).deliver_later if review.requested_by && review.requested_by != Current.user
    Activity.record!(review.version.article, decision == "approved" ? "review_approved" : "review_changes_requested", by: Current.user)
    redirect_to edit_admin_article_path(review.version.article), notice: decision == "approved" ? "Approved" : "Changes requested"
  rescue ActiveRecord::RecordNotFound
    head :forbidden
  end

  def destroy
    review = Review.find(params[:id])
    return head(:forbidden) unless review.requested_by == Current.user || Current.user.can_publish?
    review.update!(status: "cancelled", decided_at: Time.current)
    redirect_to edit_admin_article_path(review.version.article), notice: "Review withdrawn"
  end
end
