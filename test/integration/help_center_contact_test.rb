require "test_helper"

class HelpCenterContactTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @type = TicketType.create!(name: "Billing question", category: "customer", description: "Invoices and refunds")
    @type.fields.create!(label: "Invoice number", data_type: "string", visible_to_contacts: true, required_for_contacts: true)
    @internal = TicketType.create!(name: "Engineering bug", category: "back_office")
  end

  test "a question from the help center lands in the inbox and emails the link back" do
    get contact_path
    assert_response :success
    assert_select "a", text: /Billing question/
    assert_select "a", text: /Engineering bug/, count: 0

    assert_enqueued_emails 1 do
      post contact_path, params: { email: "pat@example.com", name: "Pat", body: "My invoice is wrong", from: "/a/send-an-invoice" }
    end
    thread = SupportThread.order(:id).last
    assert_equal "help_center", thread.channel
    assert_equal "conversation", thread.kind
    assert_equal "pat@example.com", thread.contact.email
    assert_equal "/a/send-an-invoice", thread.page_context
    assert_equal "help_center", thread.parts.first.channel
    assert_redirected_to %r{/t/.+\?sent=1}

    follow_redirect!
    assert_select ".sent", text: /pat@example.com/
    assert_select ".conversation", text: /My invoice is wrong/
  end

  test "a request (customer ticket) from the help center" do
    post contact_ticket_path(@type), params: { email: "pat@example.com", title: "Charged twice", description: "Twice in March",
                                               fields: { invoice_number: "INV-42" } }
    ticket = SupportThread.order(:id).last
    assert ticket.ticket?
    assert_equal [ "help_center", @type, "INV-42" ], [ ticket.channel, ticket.ticket_type, ticket.ticket_attributes["invoice_number"] ]
    assert_equal "pat@example.com", ticket.created_by_label
    follow_redirect!
    assert_select "h1", "Charged twice"
    assert_select ".status", ticket.ticket_state.external_label
    assert_select "p", text: /Invoice number: INV-42/
  end

  test "missing email or required fields re-show the form with what was typed" do
    post contact_ticket_path(@type), params: { email: "nope", title: "", fields: { invoice_number: "" }, description: "kept" }
    assert_response :unprocessable_entity
    assert_select ".errors", text: /email/
    assert_select ".errors", text: /title/
    assert_select "textarea[name=description]", text: "kept"
    assert_equal 0, SupportThread.where(channel: "help_center").count

    post contact_path, params: { email: "pat@example.com", body: "" }
    assert_response :unprocessable_entity
  end

  test "only customer ticket types can be filed" do
    get contact_ticket_path(@internal)
    assert_response :not_found
  end

  test "only local paths are kept as the page they came from" do
    post contact_path, params: { email: "pat@example.com", body: "Hi", from: "//evil.example/x" }
    assert_nil SupportThread.order(:id).last.page_context
  end

  test "inside a cross-site frame the forms work without the session's CSRF token" do
    ActionController::Base.allow_forgery_protection = true
    post contact_path, params: { email: "pat@example.com", body: "From a frame" }, headers: { "Sec-Fetch-Dest" => "iframe" }
    assert_response :redirect
    token = response.location[%r{/t/([^?]+)}, 1]
    post contact_thread_reply_path(token), params: { body: "And a reply" }, headers: { "Sec-Fetch-Dest" => "iframe" }
    assert_response :redirect
    assert_equal 2, SupportThread.order(:id).last.parts.where(author_type: "contact").count

    post contact_path, params: { email: "pat@example.com", body: "Top level, no token" }
    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "admins can hide Contact support from the help center" do
    article = publish_article(title: "Send an invoice", body: "<p>Hi</p>", chapter: create_chapter)
    sign_in_as users(:one)
    get admin_help_center_path
    assert_select "input[type=checkbox][name=contact][checked]"

    patch admin_help_center_path, params: { contact: "0" }
    assert_equal false, Setting.help_center_contact?
    sign_out

    get root_path
    assert_select "a", text: "Contact support", count: 0
    assert_select ".band", count: 0
    get search_path(q: "zzzz")
    assert_select "a", text: "Ask our team", count: 0
    post article_vote_path(article, value: -1, source: "kb"), params: { comment: "nope" }
    assert_no_match "Contact support", response.body
    get contact_path
    assert_response :not_found
    post contact_path, params: { email: "pat@example.com", body: "Hi" }
    assert_response :not_found
    assert_equal 0, SupportThread.count

    sign_in_as users(:one)
    patch admin_help_center_path, params: { contact: "1" }
    sign_out
    get root_path
    assert_select "a", text: "Contact support"
  end

  test "only admins change help center settings" do
    sign_in_as users(:two)
    patch admin_help_center_path, params: { contact: "0" }
    assert_response :forbidden
    assert Setting.help_center_contact?
  end
end
