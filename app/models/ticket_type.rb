# What a ticket captures and who sees it (S47/S48).
#   customer     always shared with the customer
#   back_office  internal unless the type is shareable; created from a conversation
#   tracker      always internal; links many conversations to one issue
class TicketType < ApplicationRecord
  CATEGORIES = %w[customer back_office tracker].freeze
  MAX_FIELDS = 50

  belongs_to :default_team, class_name: "Team", optional: true
  has_many :fields, -> { order(:position, :id) }, class_name: "TicketTypeAttribute", dependent: :destroy, inverse_of: :ticket_type
  has_many :ticket_type_states, -> { order(:position) }, dependent: :delete_all
  has_many :states, through: :ticket_type_states, source: :state
  has_many :tickets, class_name: "SupportThread", dependent: :restrict_with_error

  accepts_nested_attributes_for :fields, allow_destroy: false, reject_if: ->(a) { a[:label].blank? && a[:id].blank? }

  validates :name, presence: true, length: { maximum: 191 }
  validates :description, length: { maximum: 255 }
  validates :category, inclusion: { in: CATEGORIES }
  validate :covers_every_state_category, if: -> { persisted? || states.any? }
  validate { errors.add(:fields, "at most #{MAX_FIELDS}") if fields.size > MAX_FIELDS }
  validate { errors.add(:shareable, "isn't possible for trackers") if category == "tracker" && shareable }

  after_create :use_all_states, if: -> { ticket_type_states.empty? }
  after_create { states.reset }

  scope :live, -> { where(archived_at: nil) }
  scope :for_customers, -> { live.where(category: "customer") }

  def customer? = category == "customer"
  def shared_with_customer? = customer? || (category == "back_office" && shareable)
  def live_fields = fields.reject(&:archived_at)
  def first_state = states.live.in_order.first
  def category_label = { "customer" => "Customer", "back_office" => "Back-office", "tracker" => "Tracker" }.fetch(category)

  private
    def use_all_states
      TicketState.ensure_defaults!
      TicketState.live.in_order.each_with_index { |s, i| ticket_type_states.create!(state: s, position: i) }
    end

    def covers_every_state_category
      missing = TicketState::CATEGORIES - states.map(&:category).uniq
      errors.add(:states, "need at least one #{missing.map { _1.humanize.downcase }.to_sentence} state") if missing.any?
    end
end
