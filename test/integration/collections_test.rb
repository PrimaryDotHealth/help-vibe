require "test_helper"

class CollectionsTest < ActionDispatch::IntegrationTest
  setup do
    @scheduling = create_chapter
    @billing = create_chapter(code: "BIL", name: "Billing")
    @acme = Collection.create!(name: "Acme Clinics", slug: "acme")
    @general = Collection.create!(name: "General")
    @beta = Collection.create!(name: "Beta Health", slug: "beta")

    @shared = publish_article(title: "Reschedule a visit", body: "<p>Pick a new time for the visit.</p>", chapter: @scheduling)
    @for_acme = publish_article(title: "Acme visit codes", body: "<p>Acme uses visit codes for every visit.</p>", chapter: @scheduling)
    @for_beta = publish_article(title: "Beta invoices", body: "<p>Beta sends invoices monthly after each visit.</p>", chapter: @billing)
    @loose = publish_article(title: "Visit checklist", body: "<p>Bring your card to the visit.</p>", chapter: @scheduling)

    @shared.collections = [ @general ]
    @for_acme.collections = [ @acme ]
    @for_beta.collections = [ @beta ]
  end

  test "no collections: everything shows, as before" do
    get root_path
    assert_select "a", text: /Beta invoices/
    assert_select "a", text: /Visit checklist/
    get article_path(@for_beta)
    assert_response :success
  end

  test "the home page and chapters show only the requested collections, and empty chapters disappear" do
    get root_path(collections: "acme,general")
    assert_response :success
    assert_select "a", text: /Acme visit codes/
    assert_select "a", text: /Reschedule a visit/
    assert_select "a", text: /Beta invoices/, count: 0
    assert_select "a", text: /Visit checklist/, count: 0, message: "articles in no collection aren't in a filtered view"
    assert_select "a", text: /Billing/, count: 0, message: "a chapter with nothing in these collections is hidden"

    get chapter_path(@scheduling, collections: "acme")
    assert_select "a", text: /Acme visit codes/
    assert_select "a", text: /Reschedule a visit/, count: 0
  end

  test "links, redirects and search keep the collections, and search is filtered" do
    get root_path(collections: "acme")
    assert_select "a[href=?]", article_path(@for_acme, collections: "acme")
    assert_select "form[action^='/search'] input[type=hidden][name=collections][value=acme]"

    get search_path(q: "visit", collections: "acme")
    assert_select "a", text: /Acme visit codes/
    assert_select "a", text: /Beta invoices/, count: 0
    assert_select "a", text: /Reschedule a visit/, count: 0

    get search_path(q: @for_acme.code, collections: "acme")
    assert_redirected_to article_path(@for_acme, collections: "acme")
    get search_path(q: @for_beta.code, collections: "acme")
    assert_response :success, "a code outside the collections doesn't jump to it"
  end

  test "an article outside the collections is not found, and related articles stay inside" do
    get article_path(@for_beta, collections: "acme")
    assert_response :not_found
    get article_path(@for_acme, collections: "acme")
    assert_response :success
    assert_select "a", text: /Visit checklist/, count: 0
  end

  test "unknown collection names match nothing rather than everything" do
    get root_path(collections: "nope")
    assert_response :success
    assert_select "a", text: /Acme visit codes|Beta invoices|Visit checklist/, count: 0
  end

  test "the widget and embedded article follow the collections too" do
    get widget_search_path(q: "visit", collections: "beta")
    assert_select "a", text: /Beta invoices/
    assert_select "a", text: /Acme visit codes/, count: 0
    get embedded_article_path(@for_acme.slug, collections: "beta")
    assert_response :not_found
    get embedded_article_path(@for_beta.slug, collections: "beta")
    assert_response :success
  end

  test "the widget script passes data-collections on to the panel" do
    get embed_script_path
    assert_includes response.body, "dataset.collections"
  end

  test "publishers manage collections and put articles in them; the list filters by collection" do
    sign_in_as users(:one)
    post admin_collections_path, params: { collection: { name: "Mercy Hospital" } }
    mercy = Collection.find_by!(slug: "mercy-hospital")

    article = @loose
    patch admin_article_path(article), params: { editor: {
      version_id: article.live_version.id, title: article.live_version.title, body: "<p>Bring your card to the visit.</p>",
      main_category_id: article.main_category_id, accessibility: "public", keywords: "",
      collection_ids: [ "", mercy.id.to_s, @acme.id.to_s ] } }
    assert_equal [ @acme, mercy ].map(&:id).sort, article.reload.collection_ids.sort
    get edit_admin_article_path(article)
    assert_select "input[type=checkbox][name='editor[collection_ids][]'][checked]", count: 2

    get admin_articles_path(collection: "mercy-hospital")
    assert_select "td", text: /Visit checklist/
    assert_select "td", text: /Beta invoices/, count: 0

    get admin_collections_path
    assert_select "td", text: /Mercy Hospital/

    get admin_install_articles_path
    assert_select "h2", text: "Only some collections"
    assert_includes response.body, "?collections=acme,beta"

    delete admin_collection_path(mercy)
    assert_equal [ @acme.id ], article.reload.collection_ids
  end

  test "draft writers can see collections but not change them" do
    sign_in_as users(:writer)
    get admin_collections_path
    assert_response :success
    post admin_collections_path, params: { collection: { name: "Nope" } }
    assert_response :forbidden
  end
end
