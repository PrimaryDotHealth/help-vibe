require "test_helper"

class DeliveryTest < ActionMailer::TestCase
  test "every email turns off SendGrid link and open tracking" do
    mail = UsersMailer.invitation(users(:writer))
    settings = JSON.parse(mail["X-SMTPAPI"].value)
    assert_equal 0, settings.dig("filters", "clicktrack", "settings", "enable")
    assert_equal 0, settings.dig("filters", "opentrack", "settings", "enable")
    assert_match %r{/invitations/}, mail.body.encoded
  end

  test "SendGrid SMTP settings" do
    require Rails.root.join("config/sendgrid")
    ENV["SENDGRID_API_KEY"], old = "SG.test", ENV["SENDGRID_API_KEY"]
    s = Helpvibe.sendgrid_smtp_settings
    assert_equal [ "smtp.sendgrid.net", 587, "apikey", "SG.test" ], s.values_at(:address, :port, :user_name, :password)
  ensure
    ENV["SENDGRID_API_KEY"] = old
  end
end
