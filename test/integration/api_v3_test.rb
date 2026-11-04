require "test_helper"

class ApiV3Test < ActionDispatch::IntegrationTest
  setup do
    @chapter = create_chapter
    @public = publish_article(title: "Refund a payment", body: "<p>Open the invoice and choose Refund.</p>", chapter: @chapter, keywords: "refund")
    @internal = publish_article(title: "Staff refund rules", body: "<p>Refund limits for staff.</p>", chapter: @chapter, accessibility: "internal")
    @private = publish_article(title: "Private refund notes", body: "<p>Refund secrets.</p>", chapter: @chapter, accessibility: "private")
    @key = ApiKey.create!(name: "test", created_by: users(:one))
  end

  def auth(token = @key.token) = { "Authorization" => token }

  test "requires a valid key" do
    get api_v3_articles_path
    assert_response :forbidden
    get api_v3_articles_path, headers: auth("hv_nope")
    assert_response :unauthorized
    @key.revoke!
    get api_v3_articles_path, headers: auth
    assert_response :unauthorized
  end

  test "lists public and staff-only articles in Helpjuice's envelope, never private" do
    get api_v3_articles_path(limit: 1), headers: auth
    assert_response :success
    body = response.parsed_body
    assert_equal({ "current" => 1, "limit" => 1, "total_pages" => 2, "total_count" => 2 }, body["meta"])
    get api_v3_articles_path, headers: { "Authorization" => "Bearer #{@key.token}" }
    names = response.parsed_body["articles"].map { _1["name"] }
    assert_equal [ "Refund a payment", "Staff refund rules" ], names
    assert_equal [ 1, 0 ], response.parsed_body["articles"].map { _1["accessibility"] }
  end

  test "show by id, slug or code, with the answer body" do
    [ @public.id, @public.slug, "sch01" ].each do |id|
      get api_v3_article_path(id), headers: auth
      assert_response :success
      answer = response.parsed_body.dig("article", "answer", 0)
      assert_equal "Open the invoice and choose Refund.", answer["body_txt"]
    end
    get api_v3_article_path(@private.id), headers: auth
    assert_response :not_found
  end

  test "search and categories" do
    get api_v3_search_path(query: "refunds"), headers: auth
    assert_equal 2, response.parsed_body["articles"].size
    get api_v3_categories_path, headers: auth
    assert_equal [ "SCH" ], response.parsed_body["categories"].map { _1["code"] }
    assert_equal "api", SearchEvent.last.source
  end

  test "updated_since filter accepts Helpjuice's date format" do
    @public.update_columns(updated_at: 1.year.ago)
    get api_v3_articles_path(updated_since: 1.week.ago.strftime("%d-%m-%Y")), headers: auth
    assert_equal [ "Staff refund rules" ], response.parsed_body["articles"].map { _1["name"] }
  end
end
