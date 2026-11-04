require "test_helper"

class WidgetIdentityTest < ActionDispatch::IntegrationTest
  setup do
    chapter = create_chapter
    publish_article(title: "Public refunds", body: "<p>Refunds for everyone.</p>", chapter: chapter)
    publish_article(title: "Staff refunds", body: "<p>Refunds staff only.</p>", chapter: chapter, accessibility: "internal")
  end

  test "a staff token from our app shows staff-only articles in the widget" do
    get widget_search_path(q: "refunds")
    assert_select ".w-list a", count: 1

    post widget_session_path, params: { token: WidgetIdentity.issue(sub: "u-1", kind: "staff", name: "Dana") }, as: :json
    assert_response :success
    assert_equal "staff", response.parsed_body["kind"]

    get widget_search_path(q: "refunds")
    assert_select ".w-list a", count: 2
    assert_select ".w-foot", /Signed in as Dana/
  end

  test "patient tokens don't unlock staff content" do
    post widget_session_path, params: { token: WidgetIdentity.issue(sub: "p-1", kind: "patient") }, as: :json
    get widget_search_path(q: "refunds")
    assert_select ".w-list a", count: 1
  end

  test "bad, expired and long-lived tokens are refused" do
    post widget_session_path, params: { token: "nonsense" }, as: :json
    assert_response :unauthorized

    post widget_session_path, params: { token: WidgetIdentity.issue(sub: "u", kind: "staff", now: 1.hour.ago) }, as: :json
    assert_response :unauthorized

    long = JWT.encode({ sub: "u", kind: "staff", iat: Time.now.to_i, exp: 1.day.from_now.to_i }, WidgetIdentity.secret, "HS256")
    post widget_session_path, params: { token: long }, as: :json
    assert_response :unauthorized

    forged = JWT.encode({ sub: "u", kind: "staff", iat: Time.now.to_i, exp: 5.minutes.from_now.to_i }, "wrong secret", "HS256")
    post widget_session_path, params: { token: forged }, as: :json
    assert_response :unauthorized
  end

  test "embed.js exposes identify and the chromeless article embed works" do
    get embed_script_path
    assert_includes response.body, "identify: function"
    get embedded_article_path("SCH·01")
    assert_response :success
    assert_select "h3", "Public refunds"
  end
end
