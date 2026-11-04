# Incoming support email (SendGrid Inbound Parse -> Action Mailbox).
# Threading: the Reply-To token (support+<token>@), then In-Reply-To /
# References pointing at one of our messages. Otherwise a new conversation.
class SupportMailbox < ApplicationMailbox
  AUTO_REPLY_HEADERS = { "Auto-Submitted" => /\A(?!no\z)/i, "X-Autoreply" => /./, "X-Autorespond" => /./,
                         "Precedence" => /\A(bulk|junk|list|auto_reply)\z/i }.freeze

  def process
    return if auto_reply? || from_address.blank? || own_address?

    text = self.class.reply_text(mail)
    return if text.blank? && mail.attachments.empty?

    thread = threaded_to
    part =
      if thread && thread.contact&.email == from_address
        thread.contact_comment!(body: text, channel: "email", email_message_id: mail.message_id)
      else
        contact = Contact.for_email(from_address, name: mail[:from]&.display_names&.first)
        SupportThread.start!(contact: contact, body: text.presence || "(attachment)", channel: "email",
                             email_message_id: mail.message_id).parts.first
      end
    attach_files(part)
  rescue ActiveRecord::RecordNotUnique
    nil # the same Message-ID twice (SendGrid retry): already processed
  end

  # The new text only: cut at our marker, or at "On ... wrote:" quoting.
  def self.reply_text(mail)
    raw = mail.text_part&.decoded || (mail.html_part && Nokogiri::HTML(mail.html_part.decoded).text) ||
          (mail.multipart? ? "" : mail.decoded)
    raw = raw.to_s.encode("UTF-8", invalid: :replace, undef: :replace).gsub("\r\n", "\n")
    raw = raw.split(ThreadMailer::REPLY_MARKER).first.to_s
    raw = raw.split(/^\s*On .{0,200}wrote:\s*$/).first.to_s
    raw = raw.split(/^-{2,} ?Original Message ?-{2,}/i).first.to_s
    raw.lines.reject { _1.start_with?(">") }.join.strip.first(20_000)
  end

  private
    def from_address = mail.from&.first.to_s.downcase

    def own_address?
      domain = ENV["HELPVIBE_INBOUND_DOMAIN"].presence
      domain && from_address.end_with?("@#{domain}")
    end

    def auto_reply?
      AUTO_REPLY_HEADERS.any? { |name, pattern| mail[name] && mail[name].to_s.match?(pattern) }
    end

    def threaded_to
      token = Array(mail.recipients).filter_map { _1[/\Asupport\+([A-Za-z0-9]+)@/i, 1] }.first
      thread = SupportThread.find_by(reply_token: token) if token
      return thread if thread
      ids = [ mail.in_reply_to, mail.references ].flatten.compact.map(&:to_s)
      part_id = ids.filter_map { _1[/\Apart-(\d+)@/, 1] }.first
      thread_id = ids.filter_map { _1[/\Athread-(\d+)@/, 1] }.first
      (part_id && ThreadPart.find_by(id: part_id)&.thread) || (thread_id && SupportThread.find_by(id: thread_id))
    end

    def attach_files(part)
      return unless part
      mail.attachments.first(10).each do |a|
        next if a.decoded.bytesize > 25.megabytes
        part.files.attach(io: StringIO.new(a.decoded), filename: a.filename.to_s.presence || "attachment", content_type: a.mime_type)
      end
    end
end
