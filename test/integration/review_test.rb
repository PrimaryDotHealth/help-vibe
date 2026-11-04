require "test_helper"

class ReviewTest < ActionDispatch::IntegrationTest
  setup do
    @chapter = create_chapter
    @article = Article.start!(title: "Refund policy", category: @chapter, author: users(:writer))
    @version = @article.versions.first
    @version.save_revision!(body: "<p>Refunds within 30 days.</p>", author: users(:writer), base_revision_id: nil)
    @billing = Group.create!(name: "Billing")
    @billing.users << users(:viewer)
  end

  test "draft writer asks for review; a reviewer approves; then it can publish" do
    sign_in_as users(:writer)
    assert_emails 1 do
      perform_enqueued_jobs do
        post admin_version_reviews_path(@version), params: { reviewer_keys: [ "user:#{users(:two).id}" ], note: "Check the 30 days" }
      end
    end
    review = Review.last
    assert_equal "pending", review.status

    sign_in_as users(:two)
    get admin_articles_path(status: "review")
    assert_select ".title-cell a", "Refund policy"
    assert_select ".side .count", "1"

    post admin_article_publication_path(@article)
    assert_match "Waiting for review approval", flash[:alert]

    post decide_admin_review_path(review), params: { decision: "approved", message: "Looks right" }
    assert_equal "approved", review.reload.status
    post admin_article_publication_path(@article)
    assert @article.reload.live_version
  end

  test "rule 'all' needs every reviewer; a group member decides for the group; changes requested blocks" do
    Setting["review.rule"] = "all"
    review = Review.request!(version: @version, by: users(:writer), reviewer_keys: [ "user:#{users(:two).id}", "group:#{@billing.id}" ])
    review.decide!(user: users(:two), decision: "approved")
    assert_equal "pending", review.reload.status
    review.decide!(user: users(:viewer), decision: "changes_requested", message: "Say business days")
    assert_equal "changes_requested", review.reload.status
    assert_equal "Waiting for review approval", @version.reload.publish_blocked_for(users(:two))
    assert_nil @version.publish_blocked_for(users(:one)), "superadmins may bypass by default"
    assert_raises(ActiveRecord::RecordNotFound) { review.decide!(user: users(:writer), decision: "approved") }
  end

  test "requiring review blocks publishing until approved" do
    Setting["review.required"] = true
    assert_equal "An approved review is required before publishing", @version.publish_blocked_for(users(:two))
  end

  test "comments with a quote, resolved and reopened" do
    sign_in_as users(:two)
    post admin_version_comments_path(@version), params: { body: "Say which days", quote: "within 30 days" }
    comment = Comment.last
    assert_equal "within 30 days", comment.quote
    get edit_admin_article_path(@article)
    assert_select "#comments .comment", /Say which days/
    patch admin_comment_path(comment, resolved: 1)
    assert comment.reload.resolved_at
    patch admin_comment_path(comment, resolved: 0)
    assert_nil comment.reload.resolved_at
  end
end
