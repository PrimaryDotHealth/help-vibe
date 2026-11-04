require "application_system_test_case"

class ReviewSystemTest < ApplicationSystemTestCase
  def sign_in(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_on "Sign in"
    assert_text "Articles"
  end

  test "request a review, comment, and approve from the editor panel" do
    article = Article.start!(title: "Refund policy", category: create_chapter, author: users(:writer))
    article.versions.first.save_revision!(body: "<p>Refunds within 30 days.</p>", author: users(:writer), base_revision_id: nil)

    sign_in users(:writer)
    visit edit_admin_article_path(article)
    assert_no_button "Publish"
    select "Lee", from: "Reviewers"
    fill_in "note", with: "Check the 30 days"
    click_button "Request review"
    assert_text "Review requested"
    find("textarea[name=body]").fill_in with: "Should this say business days?"
    click_on "Comment"
    assert_selector "#comments .comment", text: "business days"
    visit admin_root_path
    click_on "Sign out"

    sign_in users(:two)
    within(".side") { click_on "Needs my review" }
    click_on "Refund policy"
    fill_in "message", with: "Fine as is"
    click_on "Approve"
    assert_text "Approved"
    click_on "Publish"
    assert_text "Published"
  end
end
