require "application_system_test_case"

class EditorTest < ApplicationSystemTestCase
  setup { @chapter = create_chapter }

  def sign_in(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_on "Sign in"
    assert_text "Articles"
  end

  test "write in the Lexxy editor, autosave, publish, and read it" do
    article = publish_article(title: "Reschedule or cancel an appointment",
                              body: "<h2>Reschedule</h2><p>Open Calendar and select the appointment.</p><h2>Cancel</h2><p>Cancelling frees the slot.</p>",
                              chapter: @chapter)
    sign_in users(:two)
    take_screenshot(html: false) if ENV["SHOTS"]

    visit edit_admin_article_path(article)
    assert_selector "lexxy-editor[connected]", wait: 5
    content = find(".lexxy-editor__content")
    content.click
    content.send_keys(" Times are shown in your time zone.")
    assert_selector ".saved", text: "Unsaved changes"
    assert_selector ".status", text: "Live, editing v2", wait: 8
    assert_selector ".saved", text: /\ASaved \d\d:\d\d\z/
    take_screenshot(html: false) if ENV["SHOTS"]

    click_on "Publish"
    assert_text "Published", wait: 10
    visit article_path(article)
    assert_text "Times are shown in your time zone."
  end
end
