require "test_helper"

class ApiV3WriteTest < ActionDispatch::IntegrationTest
  setup do
    @chapter = create_chapter
    @reader = ApiKey.create!(name: "reader", created_by: users(:one))
    @writer = ApiKey.create!(name: "writer", scope: "write", created_by: users(:one))
  end

  def as(key) = { "Authorization" => key.token }

  test "read-only keys can't write" do
    post api_v3_articles_path, params: { article: { name: "x", category_ids: [ @chapter.id ] } }, headers: as(@reader), as: :json
    assert_response :forbidden
  end

  test "create, publish, update and archive an article" do
    post api_v3_articles_path, params: { article: { name: "Refunds", description: "Full or partial", body: "<p>Open the invoice.</p>",
                                                    category_ids: [ @chapter.id ], visibility_id: 0, published: true } }, headers: as(@writer), as: :json
    assert_response :created
    json = response.parsed_body["article"]
    assert_equal [ "SCH·01", "Refunds", 0, true ], json.values_at("code", "name", "accessibility", "published")
    article = Article.find(json["id"])
    assert_equal "internal", article.accessibility

    put api_v3_article_path(article), params: { article: { body: "<p>New steps.</p>", published: true } }, headers: as(@writer), as: :json
    assert_response :success
    assert_equal "New steps.", article.reload.live_version.current_revision.body_text
    assert_equal 2, article.versions.count

    delete api_v3_article_path(article), headers: as(@writer)
    assert_response :no_content
    assert article.reload.archived_at
    assert_empty SearchIndex.search("steps", viewer: users(:one)).first
  end

  test "validation errors are 422s" do
    post api_v3_articles_path, params: { article: { name: "No chapter" } }, headers: as(@writer), as: :json
    assert_response :unprocessable_entity
    post api_v3_categories_path, params: { category: { name: "Bad", code: "toolong1" } }, headers: as(@writer), as: :json
    assert_response :unprocessable_entity
  end

  test "create a chapter" do
    post api_v3_categories_path, params: { category: { name: "Billing", code: "BIL", accessibility: 1 } }, headers: as(@writer), as: :json
    assert_response :created
    assert_equal "BIL", Category.find(response.parsed_body.dig("category", "id")).code
  end
end
