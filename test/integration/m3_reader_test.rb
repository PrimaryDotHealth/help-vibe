require "test_helper"

class M3ReaderTest < ActionDispatch::IntegrationTest
  setup do
    @chapter = create_chapter(code: "BIL", name: "Billing")
    @invoice = publish_article(title: "Send an invoice", body: "<ol><li>Open the invoice.</li><li>Choose Send.</li><li>Pick email.</li></ol>",
                               chapter: @chapter, keywords: "invoice, send")
    @paid = publish_article(title: "Mark an invoice as paid", body: "<p>Paid.</p>", chapter: @chapter, keywords: "invoice")
    @refund = publish_article(title: "Refund a payment", body: "<p>Refund.</p>", chapter: @chapter)
  end

  test "votes: one per visitor, changeable, with an optional comment after No" do
    post article_vote_path(@invoice, value: 1)
    assert_response :success
    assert_equal [ 1, 0 ], @invoice.reload.values_at(:upvotes, :downvotes)
    post article_vote_path(@invoice, value: -1)
    assert_select "input[name=comment]"
    assert_equal [ 0, 1 ], @invoice.reload.values_at(:upvotes, :downvotes), "changing your vote moves it, doesn't add one"
    post article_vote_path(@invoice, value: -1, comment: "Didn't cover partial payments")
    assert_equal 1, Vote.count
    assert_equal "Didn't cover partial payments", Vote.last.comment
  end

  test "widget votes work without the first-party session" do
    post article_vote_path(@invoice, value: 1, source: "widget")
    assert_response :success
    assert_equal "widget", Vote.last.source
  end

  test "related articles share keywords" do
    get article_path(@invoice)
    assert_select ".related a", /Mark an invoice as paid/
  end

  test "page suggestions lead the widget on matching pages" do
    rule = ContextRule.create!(name: "Invoices", url_pattern: "/billing/invoices/**", article_codes: "BIL·02, BIL·01")
    assert_equal [ @paid, @invoice ], rule.articles.to_a
    assert rule.matches?("/billing/invoices/123/edit")
    assert_not rule.matches?("/billing/claims")

    get widget_root_path(page: "/billing/invoices/42")
    assert_select ".w-label", /For this page/
    assert_select ".answer h3", "Mark an invoice as paid"

    get widget_root_path(page: "/calendar")
    assert_select ".w-label", /Most read/
  end

  test "page rules reject unknown codes" do
    rule = ContextRule.new(name: "x", url_pattern: "/x", article_codes: "BIL·01, ZZZ·99")
    assert_not rule.valid?
    assert_match "ZZZ·99", rule.errors.full_messages.join
  end

  test "the answer card shows the first steps" do
    ContextRule.create!(name: "Invoices", url_pattern: "/billing/*", article_codes: "BIL·01")
    get widget_root_path(page: "/billing/invoices")
    assert_select ".answer ol li", 3
  end

  test "Publish with a go-live time schedules instead" do
    article = Article.start!(title: "2027 fees", category: @chapter, author: users(:two))
    sign_in_as users(:two)
    go_live = 2.days.from_now.change(sec: 0)
    patch admin_article_path(article), params: { publish: "1", editor: {
      version_id: article.versions.first.id, title: "2027 fees", body: "<p>New fees</p>", main_category_id: @chapter.id,
      accessibility: "public", keywords: "", publish_at: go_live.strftime("%Y-%m-%dT%H:%M"), expire_at: "" } }
    assert_match "Scheduled", flash[:notice]
    assert_nil article.reload.live_version
    assert_equal go_live, article.versions.first.publish_at
  end
end
