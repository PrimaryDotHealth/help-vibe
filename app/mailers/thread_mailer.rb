# Support emails. By default they carry no message text ("link only"), so no
# patient details travel by email; HELPVIBE_EMAIL_MODE=full includes the text.
# Replies come back through Action Mailbox (SupportMailbox) via the Reply-To.
class ThreadMailer < ApplicationMailer
  REPLY_MARKER = "##- Reply above this line -##".freeze

  def agent_replied(part)
    @part, @thread = part, part.thread
    @full = full_mode?
    @link = contact_thread_url(@thread.generate_token_for(:contact_link))
    mail to: @thread.contact.email, subject: "New reply to your question (##{@thread.number})",
         reply_to: self.class.reply_address(@thread), message_id: "part-#{part.id}@#{message_domain}",
         references: "<thread-#{@thread.id}@#{message_domain}>"
  end

  def ticket_opened(thread)
    @thread = thread
    @link = contact_thread_url(thread.generate_token_for(:contact_link))
    mail to: thread.contact.email, subject: "We've opened a request for you (##{thread.number})", reply_to: self.class.reply_address(thread)
  end

  def ticket_state_changed(thread)
    @thread = thread
    @link = contact_thread_url(thread.generate_token_for(:contact_link))
    mail to: thread.contact.email, subject: "Your request ##{thread.number} is now: #{thread.ticket_state.external_label}",
         reply_to: self.class.reply_address(thread)
  end

  def contact_replied(part, user)
    @part, @thread = part, part.thread
    @full = full_mode?
    @link = admin_support_thread_url(@thread)
    mail to: user.email_address, subject: "##{@thread.number}: #{@thread.contact&.display_name || "A contact"} replied"
  end

  def self.reply_address(thread)
    domain = ENV["HELPVIBE_INBOUND_DOMAIN"].presence or return nil
    "support+#{thread.reply_token}@#{domain}"
  end

  private
    def full_mode? = ENV["HELPVIBE_EMAIL_MODE"] == "full"
    def message_domain = ENV.fetch("HELPVIBE_DOMAIN", "helpvibe.local")
end
