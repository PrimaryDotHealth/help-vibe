require "test_helper"

class SupportAgentTest < ActionDispatch::IntegrationTest
  setup do
    @billing = Team.create!(name: "Billing")
    @tech = Team.create!(name: "Tech")
    @billing.users << users(:two)
    @tech.users << users(:writer)
    @contact = Contact.for_email("pat@example.com", name: "Pat Doe")
    @billing_thread = SupportThread.start!(contact: @contact, body: "Invoice", channel: "widget")
    @billing_thread.update!(assignee_team: @billing)
    @tech_thread = SupportThread.start!(contact: @contact, body: "Login", channel: "widget")
    @tech_thread.update!(assignee_team: @tech)
  end

  test "agents only open their team's and unassigned conversations; admins see all" do
    sign_in_as users(:two)
    get admin_support_thread_path(@billing_thread)
    assert_response :success
    get admin_support_thread_path(@tech_thread)
    assert_response :not_found
    get admin_inbox_path(view: "all")
    assert_select ".thread-row", 1

    sign_in_as users(:one)
    get admin_support_thread_path(@tech_thread)
    assert_response :success
  end

  test "internal notes are labelled as internal for agents and never shown to the contact" do
    @billing_thread.note!(user: users(:two), body: "Check the discount code")
    sign_in_as users(:two)
    get admin_support_thread_path(@billing_thread)
    assert_select ".msg.is-note .meta", /Internal note · only your team sees this/
    assert_select ".msg.is-note .bubble", /Check the discount code/
    assert_select ".msg.me .bubble", { text: /discount code/, count: 0 }, "not styled like a sent reply"

    get contact_thread_path(@billing_thread.generate_token_for(:contact_link))
    assert_select ".bubble", { text: /discount code/, count: 0 }
  end

  test "people outside support teams don't get the inbox" do
    users(:viewer).update!(role: "viewer")
    sign_in_as users(:viewer)
    get admin_inbox_path
    assert_redirected_to root_path
  end

  test "assign, snooze, unsnooze, close" do
    sign_in_as users(:two)
    patch admin_support_thread_path(@billing_thread), params: { do: "assign", user_id: users(:one).id, team_id: @billing.id }
    assert_equal users(:one), @billing_thread.reload.assignee_user
    assert users(:one).notifications.exists?(kind: "assigned")
    assert_equal "assignment", @billing_thread.parts.last.kind

    sign_in_as users(:one)
    patch admin_support_thread_path(@billing_thread), params: { do: "snooze", until: "1h" }
    assert_equal "snoozed", @billing_thread.reload.state
    travel 61.minutes do
      UnsnoozeJob.perform_now
      assert_equal "open", @billing_thread.reload.state
    end
    patch admin_support_thread_path(@billing_thread), params: { do: "close" }
    assert_redirected_to admin_inbox_path
    assert_equal "closed", @billing_thread.reload.state
  end

  test "saved replies fill in names; article codes link only when the contact may see them" do
    chapter = create_chapter(code: "BIL", name: "Billing")
    publish_article(title: "Refunds", body: "<p>x</p>", chapter: chapter)
    publish_article(title: "Staff refund rules", body: "<p>x</p>", chapter: chapter, accessibility: "internal")
    macro = Macro.create!(name: "Hi", body: "Hi {{contact.first_name}}, {{agent.first_name}} here.")
    assert_equal "Hi Pat, Lee here.", macro.render_for(@billing_thread, users(:two))

    part = @billing_thread.reply!(user: users(:two), body: "See BIL·01 and BIL·02")
    helper = ApplicationController.new.tap { _1.request = ActionDispatch::TestRequest.create }.helpers
    html = helper.render_message(part, for_contact: true, widget: true)
    assert_includes html, ">BIL·01</a>"
    assert_not_includes html, ">BIL·02</a>", "staff-only articles aren't linked for contacts"
  end

  test "new parts are broadcast to agents, and comments to the contact" do
    assert_enqueued_jobs 2, only: Turbo::Streams::ActionBroadcastJob do
      @billing_thread.reply!(user: users(:two), body: "Hello")
    end
    assert_enqueued_jobs 1, only: Turbo::Streams::ActionBroadcastJob do
      @billing_thread.note!(user: users(:two), body: "internal")
    end
  end

  test "the access log is append-only and for superadmins" do
    sign_in_as users(:two)
    get admin_support_thread_path(@billing_thread)
    event = AuditEvent.last
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(ip: "1.2.3.4") }
    assert_raises(ActiveRecord::StatementInvalid) do
      AuditEvent.transaction(requires_new: true) { AuditEvent.where(id: event.id).update_all(ip: "1.2.3.4") }
    end
    get admin_audit_events_path
    assert_response :forbidden
    sign_in_as users(:one)
    get admin_audit_events_path(thread: @billing_thread.number)
    assert_select "td", /Conversation ##{@billing_thread.number}/
  end
end
