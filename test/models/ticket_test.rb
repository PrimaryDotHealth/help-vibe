require "test_helper"

class TicketTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @type = TicketType.find_by!(name: "Question") rescue TicketType.create!(name: "Question", category: "customer")
    @billing = TicketType.create!(name: "Billing question", category: "customer")
    @invoice = @billing.fields.create!(label: "Invoice number", data_type: "string", visible_to_contacts: true, required_for_contacts: true)
    @amount = @billing.fields.create!(label: "Amount", data_type: "decimal", visible_to_contacts: true)
    @refund = @billing.fields.create!(label: "Refund issued", data_type: "boolean", required_to_close: true)
    @reason = @billing.fields.create!(label: "Reason", data_type: "list", list_options_text: "Wrong amount\nDuplicate charge")
    @pat = Contact.for_email("pat@example.com", name: "Pat")
    @states = TicketState.all.index_by(&:category)
  end

  test "new types use every state; a type must keep one state per category" do
    assert_equal TicketState::CATEGORIES, @billing.states.in_order.map(&:category)
    @billing.state_ids = [ @states["submitted"].id ]
    assert_not @billing.valid?
    assert_match "in progress", @billing.errors.full_messages.join
  end

  test "trackers can't be shared; field keys come from labels; formats are fixed" do
    assert_not TicketType.new(name: "Outage", category: "tracker", shareable: true).valid?
    assert_equal "invoice_number", @invoice.key
    @invoice.data_type = "integer"
    assert_not @invoice.valid?
  end

  test "contacts must fill required visible fields and values are cast by format" do
    values, errors = SupportThread.ticket_fields_from(@billing, { "amount" => "12,50" }, as: :contact)
    assert_includes errors, "Invoice number is required"
    assert_includes errors, "Amount must be a number like 10.5"
    values, errors = SupportThread.ticket_fields_from(@billing, { "invoice_number" => "INV-42", "amount" => "12.50", "refund_issued" => "yes" }, as: :contact)
    assert_empty errors
    assert_equal({ "invoice_number" => "INV-42", "amount" => "12.5" }, values, "hidden fields can't be set by contacts")
  end

  test "state changes post an event, email the customer when the state says so, and resolving needs required-to-close fields" do
    ticket = SupportThread.open_ticket!(type: @billing, title: "Charged twice", description: "Twice in March", fields: { "invoice_number" => "INV-42" }, contact: @pat, channel: "widget")
    assert_equal "submitted", ticket.ticket_state.category
    assert ticket.is_shared

    assert_emails 1 do
      perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob) { ticket.change_ticket_state!(@states["waiting_on_customer"], by: users(:two)) }
    end
    assert_match "Waiting on you", ActionMailer::Base.deliveries.last.subject
    assert_equal "ticket_state_change", ticket.parts.last.kind

    @states["in_progress"].update!(notify_customer: false)
    assert_no_emails { perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob) { ticket.change_ticket_state!(@states["in_progress"], by: users(:two)) } }

    error = assert_raises(SupportThread::TicketError) { ticket.change_ticket_state!(@states["resolved"], by: users(:two)) }
    assert_match "Refund issued", error.message
    assert_empty ticket.update_ticket_fields!({ "refund_issued" => "no" }, by: users(:two))
    ticket.change_ticket_state!(@states["resolved"], by: users(:two))
    assert_equal "closed", ticket.reload.state

    ticket.contact_comment!(body: "Still charged", channel: "widget")
    assert_equal "in_progress", ticket.reload.ticket_state.category, "a customer reply reopens a resolved ticket"
    assert_equal "open", ticket.state
  end

  test "hidden-on-create fields are still editable later, and agent requirements apply only at creation" do
    @billing.fields.create!(label: "Approver", data_type: "string", hidden_on_create: true, required_for_agents: true)
    _, errors = SupportThread.ticket_fields_from(@billing, {}, as: :agent)
    assert_empty errors, "hidden fields aren't on the creation form"
    ticket = SupportThread.open_ticket!(type: @billing, title: "x", contact: @pat, by: users(:two))
    assert_empty ticket.update_ticket_fields!({ "approver" => "Dana" }, by: users(:two))
    assert_equal "Dana", ticket.reload.ticket_attributes["approver"]
  end

  test "a conversation converts into a customer ticket, keeping its history" do
    convo = SupportThread.start!(contact: @pat, body: "Wrong invoice", channel: "widget")
    convo.convert_to_ticket!(type: @billing, title: "Wrong invoice", by: users(:two))
    assert convo.reload.ticket?
    assert_equal "Wrong invoice", convo.parts.first.body
    assert_raises(SupportThread::TicketError) { convo.convert_to_ticket!(type: @billing, title: "again", by: users(:two)) }
  end

  test "back-office tickets link to the conversation and stay internal unless shareable" do
    office = TicketType.create!(name: "Refund approval", category: "back_office")
    convo = SupportThread.start!(contact: @pat, body: "Refund please", channel: "widget")
    ticket = SupportThread.open_ticket!(type: office, title: "Approve refund", by: users(:two), link_from: convo)
    assert_not ticket.is_shared
    assert_equal @pat, ticket.contact
    assert_equal [ ticket.id ], convo.links_out.pluck(:to_thread_id)
    assert_equal "link", convo.parts.last.kind
    assert_not_includes @pat.threads.where("threads.kind = 'conversation' or threads.is_shared"), ticket

    office.update!(shareable: true)
    assert SupportThread.open_ticket!(type: office, title: "Shared one", by: users(:two), link_from: convo).is_shared
  end
end
