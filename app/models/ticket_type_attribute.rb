# One field on a ticket type. The data type is fixed once created.
class TicketTypeAttribute < ApplicationRecord
  DATA_TYPES = %w[string list integer decimal boolean datetime].freeze  # "files" later

  belongs_to :ticket_type, inverse_of: :fields

  validates :label, presence: true, length: { maximum: 191 }
  validates :data_type, inclusion: { in: DATA_TYPES }
  validates :key, presence: true, format: { with: /\A[a-z][a-z0-9_]{0,62}\z/ }, uniqueness: { scope: :ticket_type_id }
  validate { errors.add(:data_type, "can't change once created; add a new field instead") if persisted? && data_type_changed? }
  validate { errors.add(:required_for_contacts, "needs the field to be visible to customers") if required_for_contacts && !visible_to_contacts }

  before_validation(on: :create) { self.key = label.to_s.parameterize(separator: "_").gsub(/\A[^a-z]+/, "").first(63).presence || "field_#{SecureRandom.hex(3)}" if key.blank? }

  def list_options = Array(options).map(&:to_s).compact_blank
  def list_options_text = list_options.join("\n")
  def list_options_text=(text)
    self.options = text.to_s.lines.map(&:strip).compact_blank.uniq
  end

  # Casts form input; returns [value, error or nil]. Blank -> nil.
  def cast(raw)
    return [ nil, nil ] if raw.nil? || raw.to_s.strip.empty?
    s = raw.to_s.strip
    case data_type
    when "string" then [ s.first(multiline ? 10_000 : 500), nil ]
    when "list" then list_options.include?(s) ? [ s, nil ] : [ nil, "isn't one of the options" ]
    when "integer" then s.match?(/\A-?\d+\z/) ? [ s.to_i, nil ] : [ nil, "must be a whole number" ]
    when "decimal" then s.match?(/\A-?\d+(\.\d+)?\z/) ? [ s.to_d.to_s, nil ] : [ nil, "must be a number like 10.5" ]
    when "boolean" then %w[true 1 yes].include?(s.downcase) ? [ true, nil ] : (%w[false 0 no].include?(s.downcase) ? [ false, nil ] : [ nil, "must be yes or no" ])
    when "datetime" then (t = Time.zone.parse(s) rescue nil) ? [ t.iso8601, nil ] : [ nil, "must be a date and time" ]
    end
  end

  def display(value)
    return "–" if value.nil? || value == ""
    case data_type
    when "boolean" then value ? "Yes" : "No"
    when "datetime" then Time.zone.parse(value.to_s)&.strftime("%-d %b %Y %H:%M") || value
    else value.to_s
    end
  end
end
