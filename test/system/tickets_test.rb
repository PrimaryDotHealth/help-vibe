require "application_system_test_case"

class TicketsSystemTest < ApplicationSystemTestCase
  setup do
    Team.create!(name: "Support").users << users(:one)
    TicketType.create!(name: "Question", category: "customer")
    billing = TicketType.create!(name: "Billing question", category: "customer")
    billing.fields.create!(label: "Invoice number", data_type: "string", required_for_agents: true)
  end

  def sign_in
    visit new_session_path
    fill_in "email_address", with: users(:one).email_address
    fill_in "password", with: "password"
    click_on "Sign in"
    assert_text "Sign out"
  end

  test "create a ticket from the Tickets page" do
    sign_in
    visit admin_tickets_path
    click_on "New ticket"
    fill_in "title", with: "My name is chris"
    fill_in "description", with: "What is going on??"
    fill_in "email", with: "chris@example.com"

    select "Billing question (Customer)", from: "ticket_type_id"
    assert_field "Invoice number *"
    assert_field "title", with: "My name is chris", wait: 5
    assert_field "description", with: "What is going on??"

    click_on "Create ticket"   # Invoice number is required: the browser refuses to submit
    assert_no_text "created"
    assert_equal 0, SupportThread.tickets.count

    fill_in "Invoice number *", with: "INV-42"
    assert_emails 1 do
      click_on "Create ticket"
      assert_text "created"
    end
    within(".ticket-card") do
      assert_text "My name is chris"
      assert_text "What is going on??"
      assert_text "INV-42"
      assert_text "by Dana"
    end
    assert_text "Customer sees \"Submitted\""

    visit admin_tickets_path
    assert_selector "table.data td a", text: "My name is chris"
  end
end
