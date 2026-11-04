require "test_helper"

class SupportMailboxTest < ActionMailbox::TestCase
  setup do
    ENV["HELPVIBE_INBOUND_DOMAIN"] = "reply.example.com"
    @contact = Contact.for_email("pat@example.com", name: "Pat")
    @thread = SupportThread.start!(contact: @contact, body: "Invoice question", channel: "widget")
  end

  teardown { ENV.delete("HELPVIBE_INBOUND_DOMAIN") }

  test "a reply to the token address joins the thread, without the quoted history" do
    receive_inbound_email_from_mail(from: "Pat <pat@example.com>", to: "support+#{@thread.reply_token}@reply.example.com",
      subject: "Re: New reply", body: "Thanks, that worked!\n\nOn Mon, 3 Nov 2026 at 10:00, Help wrote:\n> old stuff")
    assert_equal "Thanks, that worked!", @thread.parts.reload.last.body
    assert_equal "email", @thread.parts.last.channel
  end

  test "threading by In-Reply-To to one of our messages" do
    ours = @thread.reply!(user: users(:two), body: "Answer")
    receive_inbound_email_from_mail(from: "pat@example.com", to: "support@reply.example.com", subject: "Re",
      body: "Follow-up", in_reply_to: "part-#{ours.id}@helpvibe.local")
    assert_equal "Follow-up", @thread.parts.reload.last.body
  end

  test "new email starts a new conversation with an email contact" do
    assert_difference("SupportThread.count") do
      receive_inbound_email_from_mail(from: "New Person <new@example.com>", to: "support@reply.example.com", subject: "Hi", body: "I need help")
    end
    thread = SupportThread.last
    assert_equal [ "new@example.com", "New Person", "email" ], [ thread.contact.email, thread.contact.name, thread.channel ]
  end

  test "a stranger replying to someone else's token gets their own conversation" do
    assert_difference("SupportThread.count") do
      receive_inbound_email_from_mail(from: "other@example.com", to: "support+#{@thread.reply_token}@reply.example.com", body: "Hijack?")
    end
    assert_not_equal "Hijack?", @thread.parts.reload.last.body
  end

  test "auto-replies and our own addresses are ignored" do
    assert_no_difference("ThreadPart.count") do
      receive_inbound_email_from_mail(from: "pat@example.com", to: "support+#{@thread.reply_token}@reply.example.com",
        body: "I'm out of office", "Auto-Submitted" => "auto-replied")
      receive_inbound_email_from_mail(from: "support@reply.example.com", to: "support@reply.example.com", body: "loop")
    end
  end

  test "the same message twice is stored once" do
    mail = Mail.new(from: "pat@example.com", to: "support+#{@thread.reply_token}@reply.example.com", body: "Once", message_id: "<dup-1@mail.example.com>")
    ActionMailbox::InboundEmail.create_and_extract_message_id!(mail.to_s).route
    assert_nil ActionMailbox::InboundEmail.create_and_extract_message_id!(mail.to_s), "Action Mailbox drops the repeat"
    assert_equal 1, @thread.parts.where(body: "Once").count
  end
end
