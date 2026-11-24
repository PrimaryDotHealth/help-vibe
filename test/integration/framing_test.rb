require "test_helper"

class FramingTest < ActionDispatch::IntegrationTest
  setup { @article = publish_article(title: "Send an invoice", body: "<p>Hi</p>", chapter: create_chapter) }

  test "help center and embedded articles may be framed by the allowed sites only" do
    ENV["HELPVIBE_FRAME_ANCESTORS"] = "https://app.example.com"
    [ root_path, article_path(@article), embedded_article_path(@article.slug) ].each do |path|
      get path
      assert_response :success
      assert_nil response.headers["X-Frame-Options"], path
      assert_equal "frame-ancestors https://app.example.com", response.headers["Content-Security-Policy"], path
    end
    get new_session_path
    assert_equal "SAMEORIGIN", response.headers["X-Frame-Options"], "sign-in stays unframeable"
  ensure
    ENV.delete("HELPVIBE_FRAME_ANCESTORS")
  end

  test "theme is pinned only to light or dark" do
    get embedded_article_path(@article.slug, theme: "dark")
    assert_select "html[data-theme=dark]"
    get embedded_article_path(@article.slug, theme: "<script>")
    assert_select "html[data-theme]", false
  end

  test "inside a frame staff sign-in is hidden" do
    get root_path, headers: { "Sec-Fetch-Dest" => "iframe" }
    assert_select "a", text: "Staff sign in", count: 0
    get root_path
    assert_select "a", text: "Staff sign in"
  end

  test "votes from inside a cross-site frame skip CSRF; top-level votes still need it" do
    ActionController::Base.allow_forgery_protection = true
    post article_vote_path(@article, value: 1, source: "kb"), headers: { "Sec-Fetch-Dest" => "iframe" }
    assert_response :success
    assert_equal 1, Vote.where(article: @article).count

    post article_vote_path(@article, value: 1, source: "kb")
    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
