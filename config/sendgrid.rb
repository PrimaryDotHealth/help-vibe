# All email goes out through Action Mailer over SendGrid's SMTP relay when
# SENDGRID_API_KEY is set (production and development). Without it,
# production saves emails to storage/mails and development logs them.
# Tests never send.
module Helpvibe
  def self.sendgrid_smtp_settings
    {
      address: "smtp.sendgrid.net", port: 587, domain: ENV.fetch("HELPVIBE_DOMAIN", "localhost"),
      user_name: "apikey", password: ENV["SENDGRID_API_KEY"],
      authentication: :plain, enable_starttls_auto: true, open_timeout: 5, read_timeout: 10
    }
  end
end
