require "test_helper"

class AdminM2Test < ActionDispatch::IntegrationTest
  setup { @chapter = create_chapter }

  test "history compares saves and restore copies an old one into the draft" do
    article = publish_article(title: "Refunds", body: "<p>Old wording here.</p>", chapter: @chapter)
    draft = article.working_version!(author: users(:one))
    old = article.live_version.current_revision
    draft.save_revision!(body: "<p>New wording here.</p>", author: users(:one), base_revision_id: draft.current_revision_id)

    sign_in_as users(:two)
    get admin_article_history_path(article, version_id: draft.id)
    assert_response :success
    assert_select "del", /Old/
    assert_select "ins", /New/

    get admin_article_history_path(article, version_id: draft.id, against: "live")
    assert_response :success

    post restore_admin_article_history_path(article, revision_id: old.id)
    assert_redirected_to edit_admin_article_path(article)
    assert_equal "Old wording here.", draft.reload.current_revision.body_text
    assert_equal 3, draft.revisions.count, "restore adds a revision, nothing is deleted"
  end

  test "direct uploads need a signed-in editor and respect limits" do
    blob = { filename: "a.png", byte_size: 100, checksum: Digest::MD5.base64digest("x"), content_type: "image/png" }
    post rails_direct_uploads_path, params: { blob: blob }, as: :json
    assert_response :forbidden

    sign_in_as users(:writer)
    post rails_direct_uploads_path, params: { blob: blob }, as: :json
    assert_response :success
    post rails_direct_uploads_path, params: { blob: blob.merge(byte_size: 26.megabytes) }, as: :json
    assert_response :content_too_large
    post rails_direct_uploads_path, params: { blob: blob.merge(content_type: "application/x-msdownload") }, as: :json
    assert_response :unsupported_media_type
  end

  test "old Helpjuice links redirect" do
    article = publish_article(title: "Refunds", body: "<p>x</p>", chapter: @chapter)
    SlugRedirect.create!(from_path: "/en_US/billing/refunds", article: article)
    SlugRedirect.create!(from_path: "/refunds", article: article)
    get "/en_US/billing/refunds"
    assert_redirected_to article_path(article)
    assert_equal 301, response.status
    get "/refunds"
    assert_redirected_to article_path(article)
    get "/nothing-here"
    assert_response :not_found
  end

  test "admins invite people, who set a password from the emailed link" do
    sign_in_as users(:one)
    assert_emails 1 do
      perform_enqueued_jobs do
        post admin_users_path, params: { user: { email_address: "New@Example.com", first_name: "Nia", role: "draft_writer" } }
      end
    end
    assert_redirected_to admin_users_path
    invited = User.find_by!(email_address: "new@example.com")
    token = invited.generate_token_for(:invitation)
    sign_out

    get invitation_path(token)
    assert_response :success
    patch invitation_path(token), params: { password: "a-long-password", password_confirmation: "a-long-password" }
    assert_redirected_to admin_root_path
    assert invited.reload.authenticate("a-long-password")
    get invitation_path(token)
    assert_redirected_to new_session_path, "the link stops working once used"
  end

  test "people admin guards" do
    sign_in_as users(:two)
    get admin_users_path
    assert_response :forbidden

    sign_in_as users(:one)
    patch admin_user_path(users(:one)), params: { user: { role: "viewer" } }
    assert_equal "superadmin", users(:one).reload.role, "can't demote yourself"

    patch admin_user_path(users(:two)), params: { user: { active: "0", role: "collaborator" } }
    assert_not users(:two).reload.active?

    users(:two).update!(role: "admin", active: true)
    sign_in_as users(:two)
    patch admin_user_path(users(:one)), params: { user: { role: "viewer" } }
    assert_equal "superadmin", users(:one).reload.role, "admins can't change superadmins"
    patch admin_user_path(users(:writer)), params: { user: { role: "superadmin" } }
    assert_equal "draft_writer", users(:writer).reload.role, "admins can't hand out superadmin"
  end

  test "editors share a private article with a group" do
    group = Group.create!(name: "Billing")
    group.users << users(:viewer)
    article = Article.start!(title: "Secret", category: @chapter, author: users(:two))
    sign_in_as users(:two)
    patch admin_article_path(article), params: { publish: "1", editor: {
      version_id: article.versions.first.id, title: "Secret", body: "<p>for billing</p>", main_category_id: @chapter.id,
      accessibility: "private", keywords: "", accessor_keys: [ "", "group:#{group.id}" ] } }
    assert_equal [ "group:#{group.id}" ], article.reload.accessor_keys
    assert article.visible_to?(users(:viewer))
  end
end
