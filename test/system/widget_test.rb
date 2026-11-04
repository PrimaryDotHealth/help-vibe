require "application_system_test_case"

class WidgetTest < ApplicationSystemTestCase
  setup do
    chapter = create_chapter
    publish_article(title: "Refunds for everyone", body: "<p>Public refunds.</p>", chapter: chapter)
    publish_article(title: "Refund rules for staff", body: "<p>Staff refunds.</p>", chapter: chapter, accessibility: "internal")
  end

  # Cuprite raises (instead of retrying) when the page it's polling is replaced
  # mid-check, which happens once here by design. Retry just that error.
  def across_reloads(tries: 20)
    yield
  rescue Ferrum::BrowserError, Ferrum::NodeNotFoundError
    tries -= 1
    raise if tries.zero?
    sleep 0.25
    retry
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
    # The iframe reloads itself once after swapping the token for a cookie:
    # wait for that, then re-enter the frame before typing.
    across_reloads { within_frame(widget_frame) { assert_text "Signed in as Dana (staff)", wait: 8 } }
    within_frame(widget_frame) do
      fill_in "q", with: "refunds"
      find("input[name=q]").send_keys(:enter)
      assert_text "Refund rules for staff"
    end
  end
end
