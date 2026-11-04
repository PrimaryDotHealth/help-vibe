class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("HELPVIBE_MAIL_FROM", "help@example.com")
  layout "mailer"
end
