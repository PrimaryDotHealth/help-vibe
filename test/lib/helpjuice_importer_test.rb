require "test_helper"

class HelpjuiceImporterTest < ActiveSupport::TestCase
  # Stands in for Helpjuice's API v3, shaped like its documented responses.
  class FakeClient
    attr_reader :base, :requests

    def initialize(data)
      @data = data
      @base = URI("https://acme.helpjuice.com")
      @requests = []
    end

    def get(path, _params = {})
      @requests << path
      @data.fetch(path)
    end

    def each_page(path, key, _params = {})
      @requests << path
      Array(@data.dig(path, key)).each { yield _1 }
    end

    def download(url)
      url.include?("missing") ? nil : [ "\x89PNG fake".b, "image/png" ]
    end
  end

  DATA = {
    "groups" => { "groups" => [ { "id" => 7, "name" => "Support" } ] },
    "users" => { "users" => [ { "id" => 3, "email" => "Ann@acme.com", "first_name" => "Ann", "role_id" => "collaborator" } ] },
    "categories" => { "categories" => [
      { "id" => 10, "name" => "Billing / Subscription", "codename" => "billing", "accessibility" => 1, "url" => "https://acme.helpjuice.com/en_US/billing",
        "published_questions" => [ { "id" => 100 }, { "id" => 101 } ], "draft_questions" => [ { "id" => 102 } ] },
      { "id" => 11, "name" => "Payments", "parent_id" => 10, "accessibility" => 0, "codename" => "payments",
        "published_questions" => [ { "id" => 101 } ] },
      { "id" => 12, "name" => "Billing internal", "accessibility" => 0, "codename" => "billing-internal", "published_questions" => [] }
    ] },
    "articles" => { "articles" => [
      { "id" => 100, "name" => "How to pay", "codename" => "how-to-pay", "description" => "Pay an invoice", "accessibility" => 1, "published" => true,
        "views" => 42, "url" => "https://acme.helpjuice.com/en_US/billing/how-to-pay", "keywords" => [ { "id" => 1, "name" => "pay" } ],
        "answer" => [ { "body" => '<p>See <a href="https://acme.helpjuice.com/en_US/billing/refunds#steps">refunds</a>.</p><img src="https://static.helpjuice.com/x/pay.png" alt="Pay button"><img src="https://static.helpjuice.com/missing.png">' } ] },
      { "id" => 101, "name" => "Refunds", "codename" => "refunds", "accessibility" => 2, "published" => true,
        "url" => "https://acme.helpjuice.com/en_US/billing/refunds", "answer" => [ { "body" => "<p>Refund steps</p>" } ] },
      { "id" => 102, "name" => "Draft thing", "codename" => "draft-thing", "accessibility" => 1, "published" => false,
        "url" => "https://acme.helpjuice.com/en_US/billing/draft-thing" }
    ] },
    "articles/102" => { "article" => { "answer" => [ { "body" => "<p>Drafted body</p>" } ] } }
  }.freeze

  def import(**opts)
    Helpvibe::Importers::Helpjuice.new(client: FakeClient.new(DATA), author: users(:one), users: true, **opts).tap(&:call)
  end

  test "imports chapters, articles, images, links and redirects" do
    run = import.run
    assert_equal "done", run.status

    billing = Category.find_by!(slug: "billing")
    assert_equal "BIL", billing.code
    assert_equal "internal", Category.find_by!(slug: "payments").accessibility
    assert_equal billing, Category.find_by!(slug: "payments").parent
    assert_not_equal "BIL", Category.find_by!(slug: "billing-internal").code, "codes are unique"

    pay = Article.find_by!(slug: "how-to-pay")
    assert_equal "BIL·01", pay.code
    assert_equal 42, pay.views
    assert_equal "Live", pay.status_label
    assert_equal "Pay an invoice", pay.live_version.subtitle
    assert_equal "pay", pay.keyword_list
    html = pay.live_version.current_revision.body_html
    refunds = Article.find_by!(slug: "refunds")
    assert_includes html, %(href="/a/refunds#steps"), "links to other Helpjuice articles are rewritten"
    assert_includes html, "action-text-attachment", "images are re-hosted"
    assert_equal 1, ActiveStorage::Blob.count
    assert_includes run.stats["warnings"].join, "missing.png"

    assert_equal "private", refunds.accessibility
    assert_includes run.stats["warnings"].join, "is private"
    assert_equal [ Category.find_by!(slug: "payments").id ], ArticleCategory.where(article: refunds).pluck(:category_id), "also listed in"

    draft = Article.find_by!(slug: "draft-thing")
    assert_equal "Draft", draft.status_label
    assert_equal "Drafted body", draft.versions.last.current_revision.body_text

    assert_equal pay, SlugRedirect.find("/en_US/billing/how-to-pay").article
    assert_equal pay, SlugRedirect.find("/billing/how-to-pay").article
    assert User.exists?(email_address: "ann@acme.com", role: "collaborator")
    assert Group.exists?(name: "Support")
  end

  test "running it again updates instead of duplicating" do
    import
    counts = [ Article.count, Category.count, ArticleVersion.count, Revision.count, ActiveStorage::Blob.count ]
    run = import.run
    assert_equal counts, [ Article.count, Category.count, ArticleVersion.count, Revision.count, ActiveStorage::Blob.count ]
    assert_equal 3, run.stats["articles_updated"]
  end
end
