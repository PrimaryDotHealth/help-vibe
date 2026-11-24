require "application_system_test_case"

# A page on one site (localhost) framing articles from another (127.0.0.1).
class EmbedTest < ApplicationSystemTestCase
  setup do
    @article = publish_article(title: "Send an invoice to a patient", body: "<ol><li>Open the invoice.</li><li>Choose Send.</li></ol>", chapter: create_chapter)
    @server = "http://127.0.0.1:#{Capybara.current_session.server.port}"
  end

  test "one article and the whole help center work inside a cross-site iframe" do
    visit "http://localhost:#{Capybara.current_session.server.port}#{dev_embed_path(base: @server)}"

    within_frame(find("#one")) do
      assert_text "Send an invoice to a patient"
      assert_selector "html[data-theme=light]", visible: :all
      assert_selector "base[target=_blank]", visible: :all
    end
    # The article told the host page its height, which replaced the 480px default.
    height = nil
    Timeout.timeout(5) { sleep 0.1 until (height = find("#one").evaluate_script("this.offsetHeight")) < 480 }
    assert_operator height, :>, 100

    within_frame(find("#all")) do
      assert_link "Send an invoice to a patient"
      assert_no_link "Staff sign in"
      first(:link, "Send an invoice to a patient").click
      assert_selector "h1", text: "Send an invoice to a patient"
      click_on "Yes"
      assert_text "Thanks"
    end
  end

  test "a request filed from the help center inside a cross-site iframe reaches the Helpdesk" do
    type = TicketType.create!(name: "Billing question", category: "customer")
    type.fields.create!(label: "Invoice number", data_type: "string", visible_to_contacts: true, required_for_contacts: true)
    visit "http://localhost:#{Capybara.current_session.server.port}#{dev_embed_path(base: @server)}"

    within_frame(find("#all")) do
      within(".band") { click_on "Contact support" }
      assert_selector "h1", text: "Contact support"
      click_on "Billing question"
      fill_in "Your email *", with: "pat@example.com"
      fill_in "Title *", with: "Charged twice"
      fill_in "Invoice number *", with: "INV-42"
      click_on "Send request"
      assert_text "Sent. We've emailed pat@example.com"
      assert_selector "h1", text: "Charged twice"
      fill_in "body", with: "Any update?"
      click_on "Send"
      assert_text "Any update?"
    end

    ticket = SupportThread.find_by!(title: "Charged twice")
    assert_equal [ "help_center", "pat@example.com", "INV-42" ], [ ticket.channel, ticket.contact.email, ticket.ticket_attributes["invoice_number"] ]
    assert ticket.parts.exists?(kind: "comment", author_type: "contact")
  end
end
