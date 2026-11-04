require "application_system_test_case"

class WidgetTest < ApplicationSystemTestCase
  setup do
    chapter = create_chapter
    publish_article(title: "Refunds for everyone", body: "<p>Public refunds.</p>", chapter: chapter)
    publish_article(title: "Refund rules for staff", body: "<p>Staff refunds.</p>", chapter: chapter, accessibility: "internal")
  end

  def widget_frame
    find("#helpvibe").shadow_root.find("iframe")
  end

  test "a patient sees public articles in the widget" do
    visit dev_host_path(open: 1)
    within_frame(widget_frame) do
      fill_in "q", with: "refunds"
      find("input[name=q]").send_keys(:enter)
      assert_text "Refunds for everyone"
      assert_no_text "Refund rules for staff"
    end
  end

  test "our app's staff token unlocks staff-only articles inside the iframe" do
    visit dev_host_path(open: 1, staff: 1)
    within_frame(widget_frame) do
      assert_text "Signed in as Dana (staff)", wait: 8
      fill_in "q", with: "refunds"
      find("input[name=q]").send_keys(:enter)
      assert_text "Refund rules for staff"
    end
  end
end
