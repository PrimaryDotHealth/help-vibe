class ApplicationMailer < ActionMailer::Base
  # SendGrid would otherwise rewrite links (our invitation and password-reset
  # links carry tokens) and add tracking pixels. Turn both off.
  SENDGRID_NO_TRACKING = {
    filters: { clicktrack: { settings: { enable: 0 } }, opentrack: { settings: { enable: 0 } } }
  }.to_json.freeze

  default from: ENV.fetch("HELPVIBE_MAIL_FROM", "help@example.com"), "X-SMTPAPI" => SENDGRID_NO_TRACKING
  layout "mailer"
end
