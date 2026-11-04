require "test_helper"

class M3Batch3Test < ActionDispatch::IntegrationTest
  setup { @chapter = create_chapter }

  test "callouts and common questions are rendered from plain conventions" do
    body = <<~HTML
      <h2>Cancel</h2><blockquote>Caution: late fees may apply.</blockquote><blockquote>Just a quote.</blockquote>
      <h2>Common questions</h2><h3>Can I undo it?</h3><p>No, book again.</p><h3>What does the patient see?</h3><p>An email.</p>
      <h2>Next</h2><p>After.</p>
    HTML
    article = publish_article(title: "Cancel", body: body, chapter: @chapter)
    get article_path(article)
    assert_select ".note.caution .label", "Caution"
    assert_select ".note.caution", /late fees may apply/
    assert_select "blockquote", /Just a quote/
    assert_select ".qa details", 2
    assert_select ".qa details summary", "Can I undo it?"
    assert_select ".qa details p", "No, book again."
    assert_select ".toc a", 3
  end

  test "older published versions have their own address" do
    article = publish_article(title: "Fees", body: "<p>Old fees</p>", chapter: @chapter)
    v2 = article.working_version!(author: users(:one))
    v2.save_revision!(body: "<p>New fees</p>", author: users(:one), base_revision_id: v2.current_revision_id)
    v2.publish!(by: users(:one))
    get article_version_path(article, 1)
    assert_select ".rich", /Old fees/
    assert_select ".flash", /version 1/
    get article_path(article)
    assert_select ".rich", /New fees/
  end

  test "markdown converts into the draft" do
    article = publish_article(title: "Steps", body: "<p>old</p>", chapter: @chapter)
    sign_in_as users(:two)
    post admin_version_markdown_path(article.live_version), params: { markdown: "## Do it\n\n1. One\n2. Two\n\n<script>x</script>" }
    draft = article.reload.versions.max_by(&:number)
    assert draft.draft?
    html = draft.current_revision.body_html
    assert_includes html, "<h2>Do it</h2>"
    assert_includes html, "<li>One</li>"
    assert_not_includes html, "<script>"
    assert_equal "markdown", draft.current_revision.body_format
  end

  test "activity is listed" do
    sign_in_as users(:one)
    publish_article(title: "Logged", body: "<p>x</p>", chapter: @chapter)
    get admin_activities_path
    assert_select "td", "Publish"
    get admin_activities_path(type: "article")
    assert_response :success
  end

  test "webhooks admin: add, test, pause" do
    sign_in_as users(:one)
    post admin_webhooks_path, params: { webhook: { url: "https://example.com/h", event: "question_publish" } }
    hook = Webhook.last
    assert_redirected_to admin_webhook_path(hook)
    assert_enqueued_with(job: DeliverWebhookJob) { post test_admin_webhook_path(hook) }
    post toggle_admin_webhook_path(hook)
    assert_not hook.reload.enabled
  end
end
