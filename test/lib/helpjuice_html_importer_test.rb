require "test_helper"
require "tmpdir"

class HelpjuiceHtmlImporterTest < ActiveSupport::TestCase
  # No network in tests: image downloads answer with a tiny PNG while this is switched on.
  module FakeDownload
    def download(url) = Thread.current[:fake_image_download] ? [ "\x89PNG fake".b, "image/png" ] : super
  end
  Helpvibe::Importers::Helpjuice::Client.prepend(FakeDownload)

  def page(id:, name:, category_id:, body:, accessibility: 1, published: true, codename: nil, subtitle: "")
    <<~HTML
      <html><head><title></title></head><body><article class="question">
      <header><div class="article-info"><h1 class="article-name">#{name}</h1><p class="article-subtitle">#{subtitle}</p></div></header>
      <meta name="id" content="#{id}"><meta name="category_id" content="#{category_id}"><meta name="accessibility" content="#{accessibility}">
      <meta name="codename" content="#{codename || name.parameterize}"><meta name="published" content="#{published}">
      <div id="hj-article-body" class="body fr-view">#{body}</div></article></body></html>
    HTML
  end

  METADATA = {
    "billing" => { "id" => 10, "name" => "Billing", "codename" => "billing", "accessibility" => 1, "position" => 1, "parent_id" => nil, "description" => "Money" },
    "payments" => { "id" => 11, "name" => "Payments", "codename" => "payments", "accessibility" => 0, "position" => 1, "parent_id" => 10 }
  }.freeze

  setup do
    @dir = Dir.mktmpdir
    FileUtils.mkdir_p("#{@dir}/export/billing/payments")
    File.write("#{@dir}/export/metadata.json", METADATA.to_json)
    File.write("#{@dir}/export/billing/how-to-pay-2022-01-01.html", page(id: 100, name: "How to pay", category_id: 10, subtitle: "Pay an invoice",
      body: %(<h1>How to pay</h1><div class="f-tab"><p id="isPasted">See <a href="https://acme.helpjuice.com/en_US/billing/payments/refunds#steps">refunds</a> and <a href="https://acme.helpjuice.com/en_US/billing/1255-old">old</a>.</p><i class="far fa-arrows-alt" title="Move"></i><a class="delete-tab" href="#">Delete</a></div><img src="https://static.helpjuice.com/x/pay.png" alt="Pay"><img src="data:image/png;base64,AAAA">)))
    File.write("#{@dir}/export/billing/payments/refunds-2022-01-01.html", page(id: 101, name: "Refunds", category_id: 11, accessibility: 2, body: "<p>Refund steps</p>"))
    File.write("#{@dir}/export/billing/payments/old.html", page(id: 1255, name: "Old", category_id: 11, published: false, body: "<p>Draft</p>"))
    File.write("#{@dir}/export/billing/payments/empty.html", "<html><head></head><body>\n</body></html>")
  end

  teardown do
    Thread.current[:fake_image_download] = false
    FileUtils.remove_entry(@dir)
  end

  def import(location = "#{@dir}/export", **opts)
    Helpvibe::Importers::HelpjuiceHtml.new(location: location, author: users(:one), **opts).tap(&:call)
  end

  test "imports a folder: chapters, articles, drafts, cleaned bodies, images and links" do
    Thread.current[:fake_image_download] = true
    run = import.run
    assert_equal "done", run.status
    assert_equal 2, run.stats["categories"]
    assert_equal 1, run.stats["skipped"]
    assert_equal 1, run.stats["images"]
    assert_includes run.stats["warnings"].join, "empty.html: empty, skipped"

    billing = Category.find_by!(slug: "billing")
    assert billing.code.present?
    payments = Category.find_by!(slug: "payments")
    assert_equal billing, payments.parent
    assert_equal "internal", payments.accessibility

    pay = Article.find_by!(slug: "how-to-pay")
    assert_equal billing, pay.main_category
    assert_equal "Pay an invoice", pay.live_version.subtitle
    html = pay.live_version.current_revision.body_html
    assert_includes html, %(href="/a/refunds#steps"), "linked by codename"
    assert_includes html, %(href="/a/old"), "linked by id-name"
    assert_includes html, "action-text-attachment"
    assert_not_includes html, "Delete"
    assert_not_includes html, "isPasted"
    assert_not_includes html, "<h1", "repeated title heading is dropped"

    assert_equal "private", Article.find_by!(slug: "refunds").accessibility
    assert_equal "Draft", Article.find_by!(slug: "old").status_label
  end

  test "running it again updates instead of duplicating" do
    import(images: false)
    counts = [ Article.count, Category.count, ArticleVersion.count, Revision.count ]
    run = import(images: false).run
    assert_equal counts, [ Article.count, Category.count, ArticleVersion.count, Revision.count ]
    assert_equal 3, run.stats["articles_updated"]
  end

  test "imports one html file with its metadata.json" do
    run = import("#{@dir}/export/billing/payments/refunds-2022-01-01.html", metadata: "#{@dir}/export/metadata.json", images: false).run
    assert_equal 1, run.stats["articles_created"]
    refunds = Article.find_by!(slug: "refunds")
    assert_equal "payments", refunds.main_category.slug
    assert_equal "billing", refunds.main_category.parent.slug, "ancestors come along"
    assert_not Article.exists?(slug: "how-to-pay")
  end

  test "finds metadata.json in a parent folder when importing one file" do
    import("#{@dir}/export/billing/how-to-pay-2022-01-01.html", images: false)
    assert_equal "billing", Article.find_by!(slug: "how-to-pay").main_category.slug
  end

  test "without metadata, articles land in the catch-all chapter" do
    File.delete("#{@dir}/export/metadata.json")
    run = import(images: false).run
    assert_equal "IMP", Article.find_by!(slug: "refunds").main_category.code
    assert_includes run.stats["warnings"].join, "No metadata.json"
  end

  test "a folder with no html fails the run" do
    FileUtils.mkdir_p("#{@dir}/nothing")
    assert_raises(RuntimeError) { import("#{@dir}/nothing") }
    assert_equal "failed", ImportRun.order(:id).last.status
  end

  test "s3 locations are parsed" do
    assert_match Helpvibe::Importers::HelpjuiceHtml::LOCATION, "s3://bucket/some/folder/"
    assert_no_match Helpvibe::Importers::HelpjuiceHtml::LOCATION, "/etc/passwd"
  end
end
