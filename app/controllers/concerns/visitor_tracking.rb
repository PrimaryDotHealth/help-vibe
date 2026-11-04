# A daily-rotating, one-way visitor id (no raw IPs stored), used to dedupe
# votes and views. sha256(day salt, ip, user agent).
module VisitorTracking
  private
    def visitor_hash
      salt = Rails.application.key_generator.generate_key("visitor-#{Date.current.iso8601}", 32)
      Digest::SHA256.hexdigest([ salt, request.remote_ip, request.user_agent ].join("|"))
    end
end
