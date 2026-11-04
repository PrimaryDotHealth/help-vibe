require "application_system_test_case"

class SupportSystemTest < ApplicationSystemTestCase
  setup do
    @previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline   # broadcasts go out for real
    Team.create!(name: "Billing").users << users(:two)
  end

  teardown { ActiveJob::Base.queue_adapter = @previous_adapter }

  def widget_frame = find("#helpvibe").shadow_root.find("iframe")

  test "a question from the widget, answered in the inbox, appears live for the contact" do
    using_session(:contact) do
      visit dev_host_path(open: 1)
      within_frame(widget_frame) do
        click_on "Ask us"
        fill_in "email", with: "pat@example.com"
        fill_in "body", with: "My invoice shows the wrong amount"
        click_on "Send"
        assert_selector ".msg.me", text: "wrong amount"
      end
    end

    using_session(:agent) do
      visit new_session_path
      fill_in "email_address", with: users(:two).email_address
      fill_in "password", with: "password"
      click_on "Sign in"
      within(".side") { click_on "Helpdesk" }
      click_on "Unassigned"
      find(".thread-row", text: "pat@example.com").click
      fill_in "body", with: "Sorry about that, it's fixed now."
      click_on "Send reply"
      assert_selector ".msg.me", text: "fixed now"
    end

    using_session(:contact) do
      within_frame(widget_frame) do
        assert_selector ".msg.them", text: "fixed now", wait: 10   # no reload: arrives over Action Cable
      end
    end
  end
end
