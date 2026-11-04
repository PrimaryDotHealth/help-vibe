# Someone who writes in: a patient or clinic staff member identified by our
# app's widget token (external_id = token `sub`), or just an email address
# (unverified) from the widget or an inbound email.
class Contact < ApplicationRecord
  belongs_to :company, optional: true
  has_many :threads, class_name: "SupportThread", dependent: :nullify

  validates :kind, inclusion: { in: %w[patient staff unknown] }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  normalizes :email, with: ->(e) { e.to_s.strip.downcase.presence }

  def self.from_identity(identity)
    contact = find_or_initialize_by(external_id: identity.sub.to_s)
    contact.email = identity.email if identity.email.present? && !where.not(id: contact.id).exists?(email: identity.email.to_s.downcase)
    contact.name = identity.name if identity.name.present?
    contact.kind = identity.kind
    contact.email_verified_at ||= Time.current if contact.email.present?
    contact.last_seen_at = Time.current
    contact.save!
    contact
  end

  def self.for_email(email, name: nil)
    contact = find_or_initialize_by(email: email.to_s.strip.downcase)
    contact.name = name if contact.name.blank? && name.present?
    contact.save!
    contact
  end

  def display_name = name.presence || email.presence || "Visitor ##{id}"
  def first_name = display_name.split(/[\s@]/).first
  def verified? = external_id.present? || email_verified_at.present?
  def initials = display_name.split(/[\s@.]/).compact_blank.first(2).map { _1[0] }.join.upcase
end
