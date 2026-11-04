require "test_helper"

class TicketsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    Team.create!(name: "Support").users << users(:two)
    @type = TicketType.create!(name: "Billing question", category: "customer")
    @type.fields.create!(label: "Invoice number", data_type: "string", visible_to_contacts: true, required_for_contacts: true)
    @type.fields.create!(label: "Internal cost code", data_type: "string")
  end

  test "a customer submits a ticket from the widget and sees its status and visible fields only" do
    get new_widget_conversation_path
    assert_select "a", /Billing question/

    post widget_tickets_path(type: @type.id), params: { email: "pat@example.com", title: "Charged twice", description: "Twice in March", fields: { invoice_number: "" } }
    assert_response :unprocessable_entity
    assert_select ".errors", /Invoice number is required/

    post widget_tickets_path(type: @type.id), params: { email: "pat@example.com", title: "Charged twice", description: "Twice in March",
                                                        fields: { invoice_number: "INV-42", internal_cost_code: "SNEAKY" } }
    ticket = SupportThread.tickets.last
    assert_redirected_to widget_conversation_path(ticket)
    assert_nil ticket.ticket_attributes["internal_cost_code"]
    follow_redirect!
    assert_select ".answer .status", "Submitted"
    assert_select ".answer", /Invoice number: INV-42/
    assert_select ".answer", { text: /cost code/i, count: 0 }

    get widget_conversations_path
    assert_select ".w-list a", /Billing question · Submitted/
  end

  test "agents create tickets, edit fields, change state, and filter the list" do
    sign_in_as users(:two)
    post admin_tickets_path, params: { ticket_type_id: @type.id, title: "Phone request", email: "quinn@example.com", fields: { invoice_number: "INV-7" } }
    ticket = SupportThread.tickets.last
    assert_redirected_to admin_support_thread_path(ticket)
    get admin_support_thread_path(ticket)
    assert_select "select[name=ticket_state_id]"
    patch admin_support_thread_path(ticket), params: { do: "fields", fields: { invoice_number: "INV-8", internal_cost_code: "CC1" } }
    assert_equal "CC1", ticket.reload.ticket_attributes["internal_cost_code"]
    patch admin_support_thread_path(ticket), params: { do: "ticket_state", ticket_state_id: TicketState.find_by!(category: "in_progress").id }
    assert_equal "In progress", ticket.reload.ticket_state.internal_label

    get admin_tickets_path(type: @type.id)
    assert_select "td a", "Phone request"
    get admin_tickets_path(category: "tracker")
    assert_select "td a", { text: "Phone request", count: 0 }
  end

  test "a missing required field re-shows the form with what was typed" do
    @type.fields.create!(label: "Approver", data_type: "string", required_for_agents: true)
    sign_in_as users(:two)
    post admin_tickets_path, params: { ticket_type_id: @type.id, title: "Keep me", description: "and me", email: "quinn@example.com", fields: { invoice_number: "INV-1" } }
    assert_response :unprocessable_entity
    assert_select ".flash", /Approver is required/
    assert_select "input[name=title][value=?]", "Keep me"
    assert_select "textarea[name=description]", "and me"
    assert_select "input[name='fields[invoice_number]'][value=?]", "INV-1"
    assert_equal 0, SupportThread.tickets.count
  end

  test "agent-created customer tickets email the customer; internal ones don't" do
    sign_in_as users(:two)
    assert_emails 1 do
      perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
        post admin_tickets_path, params: { ticket_type_id: @type.id, title: "For Quinn", email: "quinn@example.com", fields: { invoice_number: "INV-1" } }
      end
    end
    assert_match "We've opened a request for you", ActionMailer::Base.deliveries.last.subject
    office = TicketType.create!(name: "Internal work", category: "back_office")
    assert_no_emails do
      perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob) do
        post admin_tickets_path, params: { ticket_type_id: office.id, title: "Internal", email: "quinn@example.com" }
      end
    end
  end

  test "admins edit ticket types, fields and states" do
    sign_in_as users(:one)
    post admin_ticket_types_path, params: { ticket_type: { name: "Login problem", category: "customer" } }
    type = TicketType.find_by!(name: "Login problem")
    patch admin_ticket_type_path(type), params: { ticket_type: { name: "Login problem", fields_attributes: { "0" => { label: "Browser", data_type: "list", list_options_text: "Chrome\nSafari", visible_to_contacts: "1" } } } }
    assert_equal [ "Chrome", "Safari" ], type.reload.fields.first.list_options
    patch admin_ticket_states_path.then { admin_ticket_state_path(TicketState.find_by!(category: "waiting_on_customer")) }, params: { ticket_state: { internal_label: "Waiting on customer", external_label: "We need your reply", notify_customer: "1" } }
    assert_equal "We need your reply", TicketState.find_by!(category: "waiting_on_customer").external_label
  end

  test "the admin is split into Helpdesk and Articles, Helpdesk first" do
    sign_in_as users(:one)
    get admin_root_path
    assert_redirected_to admin_inbox_path, "admins (agents) land in the Helpdesk"
    get admin_articles_path
    assert_select ".product-switch a", count: 2
    assert_select ".product-switch a:first-child", "Helpdesk"
    assert_select ".product-switch a.on", "Articles"
    assert_select ".side a.nav", { text: "Tickets", count: 0 }
    get admin_tickets_path
    assert_select ".product-switch a.on", "Helpdesk"
    assert_select ".side a.nav", text: "Tickets"
    assert_select ".side a.nav", { text: "Articles", count: 0 }
  end

  test "agents who aren't editors go straight to the inbox" do
    agent = User.create!(email_address: "agent@example.com", password: "password", role: "viewer", first_name: "Ana")
    Team.first.users << agent
    sign_in_as agent
    get admin_root_path
    assert_redirected_to admin_inbox_path
  end
end
