require "test_helper"

# M1 done-when: an editor writes and publishes an article, then readers find
# it in the help center and in the widget.
class KnowledgeBaseFlowTest < ActionDispatch::IntegrationTest
  setup { @chapter = create_chapter }

  test "write, publish, then find it in the help center and the widget" do
    sign_in_as users(:two)

    post admin_articles_path, params: { article: { title: "Refund a payment", main_category_id: @chapter.id } }
    article = Article.last
    assert_redirected_to edit_admin_article_path(article)
    get edit_admin_article_path(article)
    assert_response :success
    assert_select "lexxy-editor"

    version = article.versions.first
    patch admin_article_path(article), params: {
      publish: "1",
      editor: { version_id: version.id, title: "Refund a payment", subtitle: "Full or partial",
                body: "<h2>Refund</h2><p>Open the invoice and choose Refund.</p>",
                main_category_id: @chapter.id, accessibility: "public", keywords: "refund, chargeback" }
    }
    assert_redirected_to edit_admin_article_path(article)
    assert_equal "Live", article.reload.status_label

    sign_out
    get search_path(q: "refunds")
    assert_response :success
    assert_select ".hit h2", text: "Refund a payment"
    event = SearchEvent.last
    assert_equal "bounced", event.outcome
    get article_path(article, sid: event.id)
    assert_equal "found", event.reload.outcome, "opening a result marks the search as answered"

    get search_path(q: "sch01")
    assert_redirected_to article_path(article)

    get article_path(article)
    assert_select "h1", "Refund a payment"

    get widget_search_path(q: "chargeback")
    assert_response :success
    assert_select ".w-list a", /Refund a payment/
    assert_nil response.headers["X-Frame-Options"], "the widget must be frameable from our app"

    get widget_article_path("SCH·01")
    assert_response :success
    assert_select ".doc h3", "Refund a payment"
  end

  test "autosave writes revisions, moves a live article onto a draft, and refuses stale saves" do
    article = publish_article(title: "Original", body: "<p>v1</p>", chapter: @chapter)
    sign_in_as users(:writer)
    live = article.live_version

    post admin_version_revisions_path(live), params: { autosave: "1", body: "<p>v2 words</p>", base_revision_id: live.current_revision_id }, as: :json
    assert_response :success
    data = response.parsed_body
    assert_equal 2, data["version_number"]
    assert_equal "Live, editing v2", data["status"]
    assert_equal "v1", article.reload.live_version.current_revision.body_text, "the live copy is untouched"

    post admin_version_revisions_path(data["version_id"]), params: { body: "<p>stale</p>", base_revision_id: live.current_revision_id }, as: :json
    assert_response :conflict
  end

  test "Save on a live article creates the draft and saves, with no false conflict" do
    article = publish_article(title: "Invite a teammate", body: "<p>old</p>", chapter: @chapter)
    live = article.live_version
    sign_in_as users(:two)
    patch admin_article_path(article), params: { editor: { version_id: live.id, base_revision_id: live.current_revision_id,
      title: "Invite a teammate", body: "<p>new words</p>", main_category_id: @chapter.id, accessibility: "public", keywords: "" } }
    assert_equal "Saved", flash[:notice]
    assert_nil flash[:alert]
    assert_equal "Live, editing v2", article.reload.status_label
    assert_equal "new words", article.versions.find_by(number: 2).current_revision.body_text
    assert_equal "old", article.live_version.current_revision.body_text
  end

  test "a real conflict is still caught: someone started a draft after you opened the live article" do
    article = publish_article(title: "Fees", body: "<p>old</p>", chapter: @chapter)
    live = article.live_version
    article.working_version!(author: users(:one))            # Dana starts a draft meanwhile
    sign_in_as users(:two)
    patch admin_article_path(article), params: { editor: { version_id: live.id, base_revision_id: live.current_revision_id,
      title: "Fees", body: "<p>Lee's words</p>", main_category_id: @chapter.id, accessibility: "public", keywords: "" } }
    assert_match "Someone else changed this article", flash[:alert]
    post admin_version_revisions_path(live), params: { body: "<p>autosave</p>", base_revision_id: live.current_revision_id }, as: :json
    assert_response :conflict
  end

  test "draft writers can't publish" do
    article = Article.start!(title: "Draft", category: @chapter, author: users(:writer))
    sign_in_as users(:writer)
    post admin_article_publication_path(article)
    assert_redirected_to edit_admin_article_path(article)
    assert_match "collaborator or admin can publish", flash[:alert]
    assert_nil article.reload.live_version
  end

  test "readers and viewers can't open the admin" do
    get admin_root_path
    assert_redirected_to new_session_path
    sign_in_as users(:viewer)
    get admin_root_path
    assert_redirected_to root_path
  end

  test "internal articles 404 for the public and show for staff" do
    article = publish_article(title: "Staff only", body: "<p>secret</p>", chapter: @chapter, accessibility: "internal")
    get article_path(article)
    assert_response :not_found
    sign_in_as users(:viewer)
    get article_path(article)
    assert_response :success
  end
end
