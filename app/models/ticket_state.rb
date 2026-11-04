# A step in a ticket's life, in one of four categories (Intercom's model).
# Teammates see internal_label; customers see external_label.
class TicketState < ApplicationRecord
  CATEGORIES = %w[submitted in_progress waiting_on_customer resolved].freeze

  has_many :ticket_type_states, foreign_key: :state_id, dependent: :restrict_with_error
  validates :category, inclusion: { in: CATEGORIES }
  validates :internal_label, :external_label, presence: true

  scope :live, -> { where(archived_at: nil) }
  scope :in_order, -> { order(Arel.sql("array_position(array['submitted','in_progress','waiting_on_customer','resolved'], category::text)"), :id) }

  def resolved? = category == "resolved"

  DEFAULTS = [
    [ "submitted", "Submitted", "Submitted" ], [ "in_progress", "In progress", "In progress" ],
    [ "waiting_on_customer", "Waiting on customer", "Waiting on you" ], [ "resolved", "Resolved", "Resolved" ]
  ].freeze

  # A fresh database (loaded from structure.sql) has no rows: create the
  # four defaults the first time a ticket type needs states.
  def self.ensure_defaults!
    return if exists?
    DEFAULTS.each { |cat, internal, external| create!(category: cat, internal_label: internal, external_label: external) }
  end
end
