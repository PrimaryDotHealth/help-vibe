# API keys for /api/v3. Only a SHA-256 digest is stored; the token is shown once.
class ApiKey < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  validates :name, presence: true
  validates :scope, inclusion: { in: %w[read write] }

  scope :usable, -> { where(revoked_at: nil) }

  attr_reader :token

  before_validation on: :create do
    @token = "hv_#{SecureRandom.base58(40)}"
    self.prefix = @token.first(11)
    self.token_hash = Digest::SHA256.digest(@token)
  end

  def self.authenticate(token)
    return if token.blank?
    usable.find_by(token_hash: Digest::SHA256.digest(token.to_s))
  end

  def touch_used!
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 1.minute.ago
  end

  def revoke! = update!(revoked_at: Time.current)
end
