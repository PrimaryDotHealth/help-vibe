# The widget's idea of who is reading, from a token our app's backend signs.
#
#   payload: { sub: "user-123", email: "dana@…", name: "Dana", kind: "staff" | "patient",
#              iat: <now>, exp: <now + at most 10 minutes> }
#   signed with HS256 using HELPVIBE_WIDGET_SECRET (shared with our app's backend)
#
# M2 uses `kind` only: staff see staff-only articles in the widget. Contacts
# (patients and staff writing in to support) arrive with Part 2.
class WidgetIdentity
  MAX_TOKEN_AGE = 10.minutes
  KINDS = %w[staff patient].freeze

  Error = Class.new(StandardError)

  attr_reader :kind, :sub, :email, :name

  def initialize(kind:, sub: nil, email: nil, name: nil)
    @kind, @sub, @email, @name = kind, sub, email, name
  end

  def self.secret
    ENV["HELPVIBE_WIDGET_SECRET"].presence ||
      (Rails.env.production? ? raise(Error, "HELPVIBE_WIDGET_SECRET is not set") : Rails.application.key_generator.generate_key("helpvibe widget", 32))
  end

  def self.from_token(token)
    payload, = JWT.decode(token.to_s, secret, true, algorithm: "HS256", required_claims: %w[exp iat sub kind])
    raise Error, "token lives too long" if payload["exp"] - payload["iat"] > MAX_TOKEN_AGE
    raise Error, "unknown kind" unless KINDS.include?(payload["kind"])
    new(kind: payload["kind"], sub: payload["sub"], email: payload["email"], name: payload["name"])
  rescue JWT::DecodeError => e
    raise Error, e.message
  end

  # Used by our app's backend (and our tests) to mint a token.
  def self.issue(sub:, kind:, email: nil, name: nil, now: Time.current)
    JWT.encode({ sub:, kind:, email:, name:, iat: now.to_i, exp: (now + 5.minutes).to_i }.compact, secret, "HS256")
  end

  def staff? = kind == "staff"
  def viewer = staff? ? Visibility::Viewer.staff_token : Visibility::Viewer.anonymous
  def to_cookie = { kind:, sub:, email:, name: }
  def self.from_cookie(h) = h.is_a?(Hash) ? new(**h.symbolize_keys.slice(:kind, :sub, :email, :name)) : nil
end
