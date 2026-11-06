require "test_helper"

class InstallPagesTest < ActionDispatch::IntegrationTest
  test "admins get the helpdesk and articles install pages with real URLs" do
    sign_in_as users(:one)
    get admin_install_helpdesk_path
    assert_response :success
    assert_includes response.body, embed_script_url
    assert_select "nav.side a.nav.on", text: /Install/
    assert_select ".product-switch a.on", text: "Helpdesk"

    publish_article(title: "Send an invoice", body: "<p>Hi</p>", chapter: create_chapter)
    get admin_install_articles_path
    assert_response :success
    assert_includes response.body, "/embed/a/"
    assert_select ".product-switch a.on", text: "Articles"
  end

  test "non-admins are turned away" do
    sign_in_as users(:two)
    get admin_install_helpdesk_path
    assert_redirected_to admin_root_path
  end

  test "the secret itself is never shown" do
    before = ENV["HELPVIBE_WIDGET_SECRET"]
    ENV["HELPVIBE_WIDGET_SECRET"] = "s3cret-value-xyz"
    sign_in_as users(:one)
    get admin_install_helpdesk_path
    assert_not_includes response.body, "s3cret-value-xyz"
    assert_includes response.body, "is set on this server"
  ensure
    ENV["HELPVIBE_WIDGET_SECRET"] = before
  end

  test "reader links in the admin sidebar open in a new tab" do
    sign_in_as users(:one)
    get admin_articles_path
    assert_select "nav.side a.nav[target=_blank][rel=noopener]", text: "Help center"
    assert_select "nav.side a.nav[target=_blank][rel=noopener]", text: "Widget preview"
    assert_select "nav.side a.nav:not([target])", text: "Contact support"
  end
end
