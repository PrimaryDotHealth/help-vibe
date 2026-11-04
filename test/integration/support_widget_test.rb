require "test_helper"

class SupportWidgetTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @team = Team.create!(name: "Billing")
    @team.users << users(:two)
  end

  test "an anonymous visitor asks with an email; agents see it; the reply comes back" do
    post widget_conversations_path, params: { email: "Pat@Example.com", name: "Pat", body: "My invoice is wrong", page: "/billing/invoices", q: "invoice wrong" }
    thread = SupportThread.last
    assert_redirected_to widget_conversation_path(thread)
    assert_equal [ "pat@example.com", false, "/billing/invoices", "invoice wrong" ], [ thread.contact.email, thread.contact.verified?, thread.page_context, thread.search_query ]
    assert thread.waiting_since

    follow_redirect!
    assert_select ".msg.me .bubble", /My invoice is wrong/

    sign_in_as users(:two)
    get admin_inbox_path(view: "unassigned")
    assert_select ".thread-row", /Pat/
    get admin_support_thread_path(thread)
    assert_response :success
    assert AuditEvent.exists?(actor_type: "user", actor_id: users(:two).id, action: "view", subject_id: thread.id)

    assert_emails 1 do
      perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
        post admin_support_thread_thread_parts_path(thread), params: { body: "Sorry! Fixed. See BIL·01 for refunds." }
      end
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "pat@example.com" ], mail.to
    assert_no_match "Fixed", mail.text_part.decoded, "link-only: no message text in email"
    assert_match "/t/", mail.text_part.decoded
    post admin_support_thread_thread_parts_path(thread), params: { body: "Internal: refunded manually", note: "1" }

    thread.reload
    assert_nil thread.waiting_since
    assert thread.first_response_at
    assert_equal users(:two), thread.assignee_user, "replying takes an unassigned thread"

    sign_out
    get widget_conversation_path(thread)
    assert_select ".msg.them .bubble", /Sorry! Fixed/
    assert_select ".bubble", { text: /Internal/, count: 0 }, "internal notes never reach the contact"
  end

  test "someone typing the same email in another browser can't read earlier conversations" do
    post widget_conversations_path, params: { email: "pat@example.com", body: "First question" }
    first = SupportThread.last
    reset!
    post widget_conversations_path, params: { email: "pat@example.com", body: "Second question" }
    get widget_conversations_path
    assert_select ".w-list a", /Second question/
    assert_select ".w-list a", { text: /First question/, count: 0 }
    get widget_conversation_path(first)
    assert_response :not_found
  end

  test "contacts identified by our app's token see all their conversations" do
    token = WidgetIdentity.issue(sub: "patient-9", kind: "patient", email: "quinn@example.com", name: "Quinn")
    post widget_session_path, params: { token: token }, as: :json
    post widget_conversations_path, params: { body: "One" }
    post widget_conversations_path, params: { body: "Two" }
    contact = Contact.find_by!(external_id: "patient-9")
    assert contact.verified?
    assert_equal "patient", contact.kind
    reset!
    post widget_session_path, params: { token: WidgetIdentity.issue(sub: "patient-9", kind: "patient") }, as: :json
    get widget_conversations_path
    assert_select ".w-list a", 2
  end

  test "a contact reply reopens a closed thread and notifies the assignee" do
    post widget_conversations_path, params: { email: "pat@example.com", body: "Help" }
    thread = SupportThread.last
    thread.assign!(by: users(:two), user: users(:two))
    thread.close!(by: users(:two))
    assert_emails 1 do
      perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
        post reply_widget_conversation_path(thread), params: { body: "Still broken" }
      end
    end
    assert_equal "open", thread.reload.state
    assert thread.waiting_since
    assert users(:two).notifications.unread.exists?(thread: thread)
  end

  test "the same client_id twice saves one message" do
    post widget_conversations_path, params: { email: "pat@example.com", body: "Hi", client_id: "abc" }
    thread = SupportThread.last
    2.times { post reply_widget_conversation_path(thread), params: { body: "again", client_id: "k1" } }
    assert_equal 2, thread.parts.count
  end

  test "the email link opens the conversation without signing in" do
    contact = Contact.for_email("pat@example.com")
    thread = SupportThread.start!(contact: contact, body: "Question", channel: "email")
    token = thread.generate_token_for(:contact_link)
    get contact_thread_path(token)
    assert_response :success
    assert_select ".bubble", /Question/
    post contact_thread_reply_path(token), params: { body: "More detail" }
    assert_equal "More detail", thread.parts.last.body
    get contact_thread_path("bad-token")
    assert_response :not_found
  end

  test "suggestions while typing don't count as searches" do
    publish_article(title: "Invoice corrections", body: "<p>Fix a wrong invoice.</p>", chapter: create_chapter(code: "BIL", name: "Billing"))
    assert_no_difference("SearchEvent.count") { get widget_search_path(q: "invoice wrong", suggest: 1) }
    assert_select "turbo-frame#suggestions a", /Invoice corrections/
  end
end
