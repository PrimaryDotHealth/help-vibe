# Outgoing webhooks with Helpjuice's event names and payload shape, plus an
# HMAC-SHA256 signature (Helpjuice documents none):
#   X-Helpvibe-Signature: t=<unix>,v1=<hex hmac_sha256(secret, "<t>.<body>")>
class Webhook < ApplicationRecord
  EVENTS = %w[question_create question_update question_delete question_archive question_publish
              category_create category_update category_delete
              user_create user_update user_delete
              comment_create comment_update comment_delete].freeze

  belongs_to :created_by, class_name: "User", optional: true
  has_many :deliveries, class_name: "WebhookDelivery", dependent: :delete_all

  encrypts :secret

  validates :event, inclusion: { in: EVENTS }
  validates :url, presence: true, format: { with: %r{\Ahttps?://[^\s]+\z}, message: "must be an http(s) URL" }
  validate :public_destination, if: -> { Rails.env.production? && ENV["HELPVIBE_ALLOW_PRIVATE_WEBHOOKS"].blank? }

  before_validation { self.secret ||= "whsec_#{SecureRandom.base58(32)}" }

  scope :enabled, -> { where(enabled: true) }

  def sign(body, at: Time.current.to_i)
    "t=#{at},v1=#{OpenSSL::HMAC.hexdigest("SHA256", secret, "#{at}.#{body}")}"
  end

  # Refuse loopback, private, link-local and metadata addresses (SSRF).
  def self.private_address?(host)
    Resolv.getaddresses(host.to_s).any? do |ip|
      addr = IPAddr.new(ip)
      addr.loopback? || addr.private? || addr.link_local? || ip == "169.254.169.254" || ip.start_with?("0.")
    end
  rescue IPAddr::InvalidAddressError
    true
  end

  private
    def public_destination
      host = URI(url).host rescue nil
      errors.add(:url, "must point at a public address") if host.nil? || self.class.private_address?(host)
    end
end
