require "test_helper"

class AnalyticsTest < ActionDispatch::IntegrationTest
  test "analytics shows no-answer searches, top articles and widget pages, and exports CSV" do
    article = publish_article(title: "Refunds", body: "<p>x</p>", chapter: create_chapter)
    3.times { SearchEvent.log!(query: "Medicare crossover", results_count: 0, source: "widget", page_context: "/billing/claims") }
    SearchEvent.log!(query: "refunds", results_count: 1, source: "kb")
    ViewEvent.create!(article: article, source: "widget", page_context: "/billing/claims")
    Vote.record!(article: article, value: -1, visitor_hash: "v1", source: "kb").update!(comment: "Missing partial refunds")

    sign_in_as users(:two)
    get admin_analytics_path
    assert_response :success
    assert_select ".chart-card .big", "3"
    assert_select ".rank .q", /medicare crossover/
    assert_select "td.mono", "/billing/claims"
    assert_select ".comment", /Missing partial refunds/

    get admin_analytics_path(source: "kb", days: "7")
    assert_select ".chart-card .big", "0"

    get admin_analytics_path(format: :csv)
    assert_equal "query,searches\nmedicare crossover,3\n", response.body
  end
end
